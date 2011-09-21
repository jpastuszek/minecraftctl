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

		@collector = nil
		@processor = nil
	end

	def process(&block)
		@processor = block	
		self
	end

  def with_message_collector(collector, &operations)
		@message_queue.flush
    @collector = collector
		begin
			instance_eval &operations
		rescue Timeout::Error
			@message_queue.error "Command timed out"
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

	def start
		if @running
			@message_queue.log "Server already running"
		else
			time_operation("Server start") do
        begin
          @message_queue.log "Starting minecraft: #{@cmd}"

          pid, @stdin, stdout, stderr = Open4::popen4(@cmd)

          @out_reader = Thread.new do
            stdout.each do |line|
              #p line
              @message_queue.out(line.strip)
            end

            @message_queue.log "Minecraft exits"
            @running = false
          end

          @err_reader = Thread.new do
            stderr.each do |line|
              #p line
              @message_queue.err(line.strip)
            end
          end

          @message_queue.log "Started server process with pid: #{pid}"

          @running = true

          wait_msg do |m|
            m.msg =~ /Done \(([^n]*)ns\)!/ or m.msg =~ /Minecraft exits/
          end

          raise StartupFailedError, @cmd unless running?
        rescue Errno::ENOENT # failed to exec
          raise StartupFailedError, @cmd
        end
			end
		end
	end

	def stop
		unless @running
			@message_queue.log "Server already stopped"
		else
			command('stop') do
				time_operation("Server stop") do
					@out_reader.join
					@err_reader.join
					@message_queue.log "Server stopped"
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
		@stdin.write("#{cmd}\n")
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
		msg = @processor.call(msg) if @processor
		return unless msg
		@collector.call(msg) if @collector
	end

	def time_operation(name)
		start = Time.now
		yield
		@message_queue.log "#{name} finished in #{(Time.now - start).to_f}"
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
		@stdin.write("list\n")
		wait_msg(true){|m| m.msg =~ /Connected players:/}
	end
end

