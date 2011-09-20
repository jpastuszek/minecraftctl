require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'minecraft'

def collect_messages(mc, &block)
	msgs = []
	mc.transaction(&block).each do |msg|
		msgs << msg
	end
	msgs
end

def collect_strings(mc, &block)
	collect_messages(mc, &block).map{|msg| msg.to_s}
end

describe Minecraft do
	it "should raise Minecraft::StartupFailedError when server command is not executable" do
		@m = Minecraft.new(File.dirname(__FILE__) + '/stub_minecraftxx')
		lambda {
			collect_messages(@m) do
				start
			end
		}.should raise_error Minecraft::StartupFailedError
	end

	it "should raise Minecraft::StartupFailedError when server command is not returning expected output" do
		@m = Minecraft.new('echo hello world')
		lambda {
			collect_messages(@m) do
				start
			end
		}.should raise_error Minecraft::StartupFailedError
	end

	it "should start up" do
		@m = Minecraft.new(File.dirname(__FILE__) + '/stub_minecraft')
		msgs = collect_strings(@m) do
			start
		end
		msgs.should include "Starting minecraft server version Beta 1.7.3\n"
		msgs.should include "Done (5887241893ns)! For help, type \"help\" or \"?\"\n"
		msgs.last.should =~ /Server start finished/
	end

	describe 'while running' do
		before :all do
			@m = Minecraft.new(File.dirname(__FILE__) + '/stub_minecraft')
			collect_strings(@m) do
				start
			end
		end

		it "responds to list command" do
			msgs = []
			@m.transaction do
				list
			end.each do |msg|
				msgs << msg
			end

			msgs.should == ["Connected players: kazuya\n"]
		end

		after :all do
			@m.transaction do
				stop
			end
		end
	end
end
