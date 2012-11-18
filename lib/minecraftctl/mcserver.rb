require 'pty'
require 'thread'
require 'tty-process-ctl'

class MCServer
	def initialize(command, options = {})
		@command = command
		@options = {
			start_timeout: 120,
			stop_timeout: 120,
			timeout: 20,
		}.merge(options)
		@process = nil
	end

	def start(&block)
		return if running?
		@process = TTYProcessCtl.new(@command)

		@process.each_until(/Done/, timeout: @options[:start_timeout], &block)
	end

	def console(command, &block)
		@process.send_command(command)
		@process.send_command('list')
		@process.each_until_exclude(/There are .* players online/, timeout: @options[:timeout], &block)
	end
	
	def stop(&block)
		return unless running?

		@process.send_command('stop')
		@process.each(timeout: @options[:stop_timeout], &block)
	end

	def running?
		@process and @process.alive?
	end
end

