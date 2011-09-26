require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'httpclient'
require 'timeout'
require 'spawn'

$url = 'http://localhost:25560/'

def start_stub
	pid, stdin, stdout, stderr = Spawn::spawn(File.dirname(__FILE__) + '/../bin/minecraftctlserver -c ./minecraft ' + File.dirname(__FILE__) + '/stub_server')

	c = HTTPClient.new
	Timeout.timeout(10) do
		begin
			@pid_file = c.get_content($url + "pid_file").strip
		rescue Errno::ECONNREFUSED
			sleep 0.1
			retry
		end
	end
end

def stop_stub
	HTTPClient.new.post_content($url, 'shutdown')

	# wait pid lock release
	File.open(@pid_file) do |pf|
		pf.flock(File::LOCK_EX)
	end
end

describe 'minecraftctlserver' do
	describe 'while server ready it should respond to' do
		before :all do
			start_stub
		end

		it 'GET /pid_file with absolute pid file path' do
			HTTPClient.new.get_content($url + 'pid_file').should match(%r{/.*spec/stub_server/minecraftctlserver.pid})
		end

		it 'GET / with API command list' do
			HTTPClient.new.get_content($url).should include 'minecraft control server API'
		end

		it 'GET /pid with PID number of control server process' do
			HTTPClient.new.get_content($url + 'pid').to_i.should > 0
		end

		it 'POST /server/console list command' do
			HTTPClient.new.post_content($url + 'server', 'console list').should == "Connected players: kazuya\n"
		end

		it 'stop and start with POST /server stop and POST /server start' do
			HTTPClient.new.post_content($url + 'server', 'stop').should include "Server stopped\n"
			HTTPClient.new.post_content($url + 'server', 'start').should include "Done (5887241893ns)! For help, type \"help\" or \"?\"\n"
		end

		after :all do
			stop_stub
		end
	end
end

