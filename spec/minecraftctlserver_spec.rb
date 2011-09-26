require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'httpclient'
require 'timeout'
require 'spawn'

$url = 'http://localhost:25560/'

def start_stub(wait = true)
	pid, stdin, stdout, stderr = Spawn::spawn(File.dirname(__FILE__) + '/../bin/minecraftctlserver -c ./minecraft ' + File.dirname(__FILE__) + '/stub_server')

	if wait
		c = HTTPClient.new
		Timeout.timeout(10) do
			begin
				c.get_content($url + "server/status")
			rescue Errno::ECONNREFUSED
				sleep 0.4
				retry
			end
		end
	end
end

def stop_stub
	HTTPClient.new.post_content($url + 'shutdown', '')

	Timeout.timeout(10) do
		begin
			loop do
				HTTPClient.new.get_content($url + "server/status")
				sleep 0.4
			end
		rescue Errno::ECONNREFUSED
		rescue => e
			puts "got different error: #{e}"
		end
	end
	sleep 0.2
end

describe 'minecraftctlserver' do
	describe 'text mode HTTP' do
		describe  'server startup' do
			before :all do
				start_stub(false)
			end

			it 'should start the minecraft server and respond to status command when ready' do
				Timeout.timeout(10) do
					out = nil
					begin
						out = HTTPClient.new.get_content($url + "server/status")
					rescue Errno::ECONNREFUSED
						sleep 0.4
						retry
					end

					out.should =~ /running/
				end
			end

			after :all do
				stop_stub
			end
		end

		describe 'while server ready' do
			before :all do
				start_stub
			end

			it 'should respond to console list command' do
				HTTPClient.new.post_content($url + "server/console", 'list').should == "Connected players: kazuya\n"
			end

			it 'should stop and start with POST /server start and POST /server stop' do
				HTTPClient.new.post_content($url + "server/stop", '').should include "Server stopped\n"
				HTTPClient.new.post_content($url + "server/start", '').should include 'Done (5887241893ns)! For help, type "help" or "?"'
			end

			it 'should respond to GET /' do
				HTTPClient.new.get_content($url).should include "show log output generated"
			end

			after :all do
				stop_stub
			end
		end
	end
end

