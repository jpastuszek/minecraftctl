class MessageCollector
	def initialize(&operation)
		@operation = operation
	end

	def self.for(minecraft, &operations)
		self.new do |collector|
			minecraft.with_message_collector(collector, &operations)
		end
	end

	def collect(msg)
		@collector.call(msg)
	end

	def each(&collector)
		@collector = collector
		@operation.call(method(:collect))
	end
end

