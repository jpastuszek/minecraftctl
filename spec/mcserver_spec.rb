require_relative 'spec_helper'

describe MCServer do
	subject do
		MCServer.new('spec/minecraft --delay 0.001')
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
			subject.start.to_a
			messages = subject.stop.to_a
			messages.first.should == '2011-09-19 22:12:00 [INFO] Stopping server'
			messages.last.should == '2011-09-19 22:12:00 [INFO] Saving chunks'
			subject.should_not be_running
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

	describe 'console' do
		it 'should support sending arbitary console commands' do
			subject.start.to_a
			subject.console('list').to_a.should == [
				'2012-11-18 16:35:34 [INFO] There are 2/20 players online:',
				'2012-11-18 16:35:34 [INFO] kazuya, emila'
			]

			subject.console('help help').to_a.should == ['2012-11-18 15:53:28 [INFO] Usage: /help [page|command name]']
		end

		describe 'timeout' do
			it 'sending arbitary console commands' do
				subject = MCServer.new('spec/minecraft --delay 0.002', timeout: 0.001)
				subject.start.to_a

				lambda {
					subject.console('list').to_a
				}.should raise_error Timeout::Error
			end
		end
	end
end

