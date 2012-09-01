require 'pty'
require 'thread'

class MCServer
	class MCProcess
		class Message < String
			class OutOfBand < Message
			end
		end

		def initialize(command)
			@max_queue = 4000
			@command = command

			@out_queue = Queue.new
			@messages = []

			@r, @w, @pid = PTY.spawn(@command)
			@thread = Thread.start do
				abort_on_exception = true
				@r.each_line do |line|
					enqueue_message line
				end
				enqueue_out_of_band_message 'exit'
			end
		end

		def enqueue_message(message)
			@out_queue << Message.new(message)
			@out_queue.pop while @out_queue.length > @max_queue
		end

		def enqueue_out_of_band_message(message)
			@out_queue << Message::OutOfBand.new(message)
		end

		def running?
			! PTY.check(@pid) and @thread.alive?
		end

		def send_command(command)
			@w.puts command
		end

		def messages
			flush
			@messages.join
		end

		def each
			flush
			loop do
				message = @out_queue.pop
				break if message.is_a? Message::OutOfBand and message == 'exit'
				@messages << message
				yield message 
			end
		end

		def each_until(pattern)
			each do |message|
				yield message
				break if message =~ pattern
			end
		end

		def each_until_exclude(pattern)
			each do |message|
				break if message =~ pattern
				yield message
			end
		end

		def flush
			loop do
				@messages << @out_queue.pop(true)
			end
		rescue ThreadError
		end
	end

	def initialize(command, options)
		@command = command
	end

	def start
		return if running?

		@process = MCProcess.new(@command)
		@process.each_until(/Done/) do |message|
			yield message
		end
	end

	def console(command)
		@process.send_command(command)
		@process.send_command('list')
		@process.each_until_exclude(/There are .* players online/) do |message|
			yield message
		end
	end
	
	def stop
		return unless running?

		@process.send_command('stop')
		@process.each do |message|
			yield message
		end
	end

	def running?
		return nil unless @process
		@process.running?
	end
end

