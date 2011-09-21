require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'message_collector'

describe MessageCollector do
  it 'should collect messages via passed proc call' do
    mc = MessageCollector.new do |collector|
      collector.call(:test1)
      collector.call(:test2)
    end

    msgs = []
    mc.each do |msg|
      msgs << msg
    end

    msgs.should == [:test1, :test2]
  end
end

