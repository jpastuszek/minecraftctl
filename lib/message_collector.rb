class MessageCollector
  def initialize(&operation)
    @operation = operation
  end

  def collect(msg)
    @collector.call(msg)
  end

  def each(&collector)
    @collector = collector
    @operation.call(method(:collect))
  end
end

