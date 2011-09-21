require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'httpclient'
require 'open4'
require 'timeout'

describe 'minecraftctlserver' do
  describe 'text mode HTTP server' do
    before :all do
      @pid, stdin, stdout, stderr = Open4::popen4(File.dirname(__FILE__) + '/../bin/minecraftctlserver -c ./minecraft ' + File.dirname(__FILE__) + '/stub_server')
    end

    it 'should start the minecraft server and respond to status command when ready' do
      c = HTTPClient.new

      Timeout.timeout(10) do
        out = nil
        begin
          out = c.get_content("http://localhost:25560/status")
        rescue Errno::ECONNREFUSED
          sleep 0.1
          retry
        end

        out.should =~ /Minecraft server is running with pid:/
      end
    end

    after :all do
      Process.kill('TERM', @pid)
      Process.wait(@pid)
    end
  end
end
