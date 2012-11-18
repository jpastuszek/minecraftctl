require_relative 'spec_helper'

describe MCServer do
	subject do
		MCServer.new('spec/minecraft')
	end

	before :each do
		subject.stop if subject.running?
	end

	describe 'livecycle' do
		it 'should start' do
			messages = subject.start.to_a
			messages.first.should == '151 recipes'
			messages.last.should == '2011-09-10 12:59:01 [INFO] Done (5887241893ns)! For help, type "help" or "?"'
			subject.should be_running
		end

		it 'should stop' do
			subject.start
			messages = subject.stop.to_a
			messages.first.should == 'stop'
			messages.last.should == '2011-09-19 22:12:00 [INFO] Saving chunks'
			subject.should_not be_running
		end
	end

	describe 'timeout' do
		it 'start' do
			subject = MCServer.new('spec/minecraft --delay 0.002 --exit', start_timeout: 0.001)

			lambda {
				subject.start.to_a
			}.should raise_error Timeout::Error
		end

		it 'stop' do
			subject = MCServer.new('spec/minecraft --delay 0.002', stop_timeout: 0.001)
			subject.start.to_a

			lambda {
				subject.stop.to_a
			}.should raise_error Timeout::Error
		end
	end
end

