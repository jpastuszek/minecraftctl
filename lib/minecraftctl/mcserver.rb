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
		@process.flush
		@process.send_command(command)
		if command.strip == 'help help'
			sync('help list', /Usage: \/list/, @options[:timeout], &block)
		else
			sync('help help', /Usage: \/help/, @options[:timeout], &block)
		end
	end
	
	def stop(&block)
		return unless running?
		@process.flush
		@process.send_command('stop')
		@process.each(timeout: @options[:stop_timeout], &block)
	end

	def running?
		@process and @process.alive?
	end

	private

	def sync(detector_command, detector_response, timeout = nil, &block)
		@process.send_command(detector_command)
		@process.each_until_exclude(detector_response, timeout: timeout, &block)
	end
end

