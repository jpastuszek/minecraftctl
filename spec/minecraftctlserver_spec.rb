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

		it 'GET /pid_file with absolute PID file path' do
			get('/pid_file').should match(%r{/.*spec/stub_server/minecraftctlserver.pid\n$})
		end

		it 'GET /log_file with absolute log file path' do
			get('/log_file').should match(%r{/.*spec/stub_server/minecraftctlserver.log\n$})
		end

		it 'GET /pid with PID number of control server process' do
			get('/pid').to_i.should > 0
		end

		it 'GET /dir with absolute directory path where minecraft server is running from' do
			get('/dir').should match(%r{/.*spec/stub_server\n$})
		end

		it 'GET /out with content of minecraft server output' do
			get('/out').should include "Loading properties\n"
		end

		it 'stop and start with POST /server stop and POST /server start' do
			post('/server', 'stop').should include "Server stopped\n"
			post('/server', 'start').should include "Done (5887241893ns)! For help, type \"help\" or \"?\"\n"
		end

		it 'POST /server start with server aleady running' do
			post('/server', 'start').should include "Server already running\n"
		end

		it 'GET /server/status with running' do
			get('/server/status').should == "running\n"
		end

		it 'GET /server/pid with PID number of minecraft server process' do
			get('/server/pid').to_i.should > 0
		end
		
		it 'POST /server/console list with list of connected players' do
			post('/server', 'console list').should == "Connected players: kazuya\n"
		end

		it 'POST /server/console with error' do
			post('/server', 'console').should == "Console command not specified; try 'console help'\n"
		end

		it 'POST / blah with error' do
			post('/', 'blah').should == "Unknown POST argument: blah for path: /\n"
		end

		describe '(having minecraft server stopped)' do
			before :all do
				post('/server', 'stop')
			end

			it 'POST /server stop with server aleady stopped' do
				post('/server', 'stop').should include "Server already stopped\n"
			end

			it 'GET /server/status with stopped' do
				get('/server/status').should == "stopped\n"
			end

			it 'GET /server/pid with error' do
				get('/server/pid').should == "Server not running\n"
			end

			it 'POST /server/console list with error' do
				post('/server', 'console list').should == "Server not running\n"
			end

			after :all do
				post('/server', 'start')
			end
		end

		after :all do
			stop_stub
		end
	end
end

