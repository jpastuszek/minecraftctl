require 'timeout'
require 'open4'
Thread.abort_on_exception = true

class Minecraft
	class HistoryQueue < Queue
		def initialize
			@history = []
      super
		end

		def flush
			until empty? 
        msg = pop(true)
				yield msg if block_given?
			end
		end

    def history
      flush
      @history
    end

    def pop(blocking = false)
				msg = super(blocking)
				@history << msg
        msg
    end
	end

  class MessageQueue < HistoryQueue
    class Message
      def initialize(msg)
        @msg = msg
      end

      attr_reader :msg

      def to_s
        @msg
      end

      class Internal < Message
        def initialize(msg)
          super(msg)
        end
      end

      class InternalError < Message
        def initialize(msg)
          super(msg)
        end
      end

      class Out < Message
        def initialize(msg)
          super(msg)
        end
      end

      class Err < Message
        def initialize(line)
          x, @time, @level, msg = *line.match(/^([^ ]* [^ ]*) \[([^\]]*)\] (.*)/)
          msg = line unless @time and @level and msg
          super(msg)
        end

        attr_reader :time, :level
      end
    end

    def initialize
      super
    end

    def out(msg)
      push Message::Out.new(msg)
    end

    def err(msg)
      push Message::Err.new(msg)
    end

    def log(msg)
      push Message::Internal.new(msg)
    end

    def error(msg)
      push Message::InternalError.new(msg)
    end
  end

	class StartupFailedError < RuntimeError
		def initialize(command)
			super "failed to start process: #{command}"
		end
	end

	def initialize(cmd)
		@cmd = cmd
		@in_queue = Queue.new
		@message_queue = MessageQueue.new

		@running = false
    @server_pid = nil

		@collector = nil
	end

  attr_reader :server_pid

  def with_message_collector(collector, &operations)
		@message_queue.flush
    @collector = collector
		begin
			instance_eval &operations
		rescue Timeout::Error
			error "Command timed out"
		ensure
			@message_queue.flush do |msg|
				collect(msg)
			end
      @collector = nil
		end
  end

	def running?
		@running
	end

  def log(msg)
			@message_queue.log(msg)
  end

  def error(msg)
			@message_queue.error(msg)
  end

	def start
		if @running
			log "Server already running"
		else
			time_operation("Server start") do
        begin
          log "Starting minecraft: #{@cmd}"

          pid, stdin, stdout, stderr = Open4::popen4(@cmd)
          @server_pid = pid

          log "Started server process with pid: #{@server_pid}"

          @in_writter = Thread.new do
            begin
              loop do
                msg = @in_queue.pop
                stdin.write(msg)
              end
            rescue IOError, Errno::EPIPE
            end
          end

          @err_reader = Thread.new do
            begin
              stderr.each do |line|
                @message_queue.err(line.strip)
              end
            rescue IOError
            end
          end

          @out_reader = Thread.new do
            begin
              stdout.each do |line|
                @message_queue.out(line.strip)
              end
            rescue IOError
            ensure
              log "Minecraft exits"
              @running = false
              @in_writter.kill
              @err_reader.kill
            end
          end

          @running = true

          wait_msg do |m|
            m.msg =~ /Done \(([^n]*)ns\)!/ or m.msg =~ /Minecraft exits/
          end

          unless running?
            Process.wait(@server_pid)
            raise StartupFailedError, @cmd 
          end
        rescue Errno::ENOENT
            raise StartupFailedError, @cmd 
        end
      end
		end
	end

	def stop
		unless @running
			log "Server already stopped"
		else
			command('stop') do
				time_operation("Server stop") do
          Process.wait(@server_pid)
					log "Server stopped"
				end

				wait_msg{|m| m.msg == "Server stopped"}
			end
		end
	end

	def save_all
		command('save-all') do
			time_operation("Save") do
				wait_msg{|m| m.msg =~ /Save complete/}
			end
		end
	end

	def list
		command('list') do
			wait_msg{|m| m.msg =~ /Connected players:/}
		end
	end

  def method_missing(m, *args)
    command(([m.to_s.tr('_', '-')] + args).join(' '))
  end

	def command(cmd)
		raise RuntimeError, "server not running" unless @running
		@in_queue << "#{cmd}\n"
		if block_given?
			yield 
		else
			active_wait
		end
	end

  def history
    @message_queue.history
  end

	private

	def collect(msg)
		@collector.call(msg) if @collector
	end

	def time_operation(name)
		start = Time.now
		yield
		log "#{name} finished in #{(Time.now - start).to_f}"
	end

	def wait_msg(discard = false, timeout = 20)
		Timeout::timeout(timeout) do
      loop do
        msg = @message_queue.pop
        if yield msg
          collect(msg) unless discard
          break
        end

        collect(msg)
      end
		end
	end

	def active_wait
		@in_queue << "list\n"
		wait_msg(true){|m| m.msg =~ /Connected players:/}
	end
end

