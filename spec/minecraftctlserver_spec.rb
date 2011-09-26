require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'httpclient'
require 'timeout'
require 'spawn'

$url = 'http://localhost:25560'

def get(uri)
	HTTPClient.new.get_content($url + uri)
end

def post(uri, data)
	HTTPClient.new.post_content($url + uri, data)
end

def start_stub
	pid, stdin, stdout, stderr = Spawn::spawn(File.dirname(__FILE__) + '/../bin/minecraftctlserver -c ./minecraft ' + File.dirname(__FILE__) + '/stub_server')

	Timeout.timeout(10) do
		begin
			@pid_file = get('/pid_file').strip
		rescue Errno::ECONNREFUSED
			sleep 0.1
			retry
		end
	end
end

def stop_stub
	post('/', 'shutdown')

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

		it 'GET / with API command list' do
			get('/').should include 'minecraft control server API'
		end

		it 'GET /pid_file with absolute pid file path' do
			get('/pid_file').should match(%r{/.*spec/stub_server/minecraftctlserver.pid})
		end

		it 'GET /pid with PID number of control server process' do
			get('/pid').to_i.should > 0
		end

		it 'POST /server/console list command' do
			post('/server', 'console list').should == "Connected players: kazuya\n"
		end

		it 'stop and start with POST /server stop and POST /server start' do
			post('/server', 'stop').should include "Server stopped\n"
			post('/server', 'start').should include "Done (5887241893ns)! For help, type \"help\" or \"?\"\n"
		end

		after :all do
			stop_stub
		end
	end
end

