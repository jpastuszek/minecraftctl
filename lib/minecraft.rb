require 'timeout'
require 'open4'
Thread.abort_on_exception = true

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
    def initialize
			@brake_cond = nil
      super
    end

		def wait(discard = false, &block)
			@brake_cond = block
			@discard = discard
		end

		def each
			loop do
				msg = pop
				if @brake_cond and @brake_cond.call(msg)
					yield msg unless @discard
					return
				end
				yield msg
			end
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
		@out_queue = MessageQueue.new

		@running = false

		@history = []

		@collector = nil
		@processor = nil
	end

	def process(&block)
		@processor = block	
		self
	end

  def with_message_collector(collector, &operations)
		@out_queue.flush
    @collector = collector
		begin
			instance_eval &operations
		rescue Timeout::Error
			internal_error "Command timed out"
		ensure
			@out_queue.flush do |msg|
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
			internal_msg "Server already running"
		else
			time_operation("Server start") do
        begin
          internal_msg "Starting minecraft: #{@cmd}"

          pid, @stdin, stdout, stderr = Open4::popen4(@cmd)

          @out_reader = Thread.new do
            stdout.each do |line|
              #p line
              @out_queue << Message::Out.new(line.strip)
            end

            internal_msg "Minecraft exits"
            @running = false
          end

          @err_reader = Thread.new do
            stderr.each do |line|
              #p line
              @out_queue << Message::Err.new(line.strip)
            end
          end

          internal_msg "Started server process with pid: #{pid}"

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
			internal_msg "Server already stopped"
		else
			command('stop') do
				time_operation("Server stop") do
					@out_reader.join
					@err_reader.join
					internal_msg "Server stopped"
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
    @out_queue.history
  end

	private

	def collect(msg)
		msg = @processor.call(msg) if @processor
		return unless msg
		@collector.call(msg) if @collector
	end

	def internal_msg(msg)
		@out_queue << Message::Internal.new(msg)
	end

	def internal_error(msg)
		@out_queue << Message::InternalError.new(msg)
	end

	def time_operation(name)
		start = Time.now
		yield
		internal_msg "#{name} finished in #{(Time.now - start).to_f}"
	end

	def wait_msg(discard = false, timeout = 20, &block)
		Timeout::timeout(timeout) do
			# set wait contition
			@out_queue.wait(discard, &block)

			# pass messages to collector if one defined
			@out_queue.each do |msg|
				collect(msg)
			end
		end
	end

	def active_wait
		@stdin.write("list\n")
		wait_msg(true){|m| m.msg =~ /Connected players:/}
	end
end

