require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'minecraft'

describe Minecraft do
	it "should raise Minecraft::StartupFailedError when server command is not executable" do
		@m = Minecraft.new(File.dirname(__FILE__) + '/stub_minecraftxx')
		lambda {
      @m.start
		}.should raise_error Minecraft::StartupFailedError
	end

	it "should raise Minecraft::StartupFailedError when server command is not returning expected output" do
		@m = Minecraft.new('echo hello world')
		lambda {
      @m.start
		}.should raise_error Minecraft::StartupFailedError
	end

	it "should start up" do
		@m = Minecraft.new(File.dirname(__FILE__) + '/stub_minecraft')
    @m.start

    msgs = @m.history.map{|m| m.msg}

		msgs.should include "Starting minecraft server version Beta 1.7.3"
		msgs.should include "Done (5887241893ns)! For help, type \"help\" or \"?\""
		msgs.last.should =~ /Server start finished/
	end

	describe 'while running' do
		before :all do
			@m = Minecraft.new(File.dirname(__FILE__) + '/stub_minecraft')
      @m.start
		end

		it "responds to list command" do
      @m.list
      msgs = @m.history.map{|m| m.msg}
			msgs.last.should == 'Connected players: kazuya'
		end

		after :all do
      @m.stop
		end
	end
end
