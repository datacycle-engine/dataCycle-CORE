module DataCycleCore
  class Callbacks
    def initialize(block = nil)
      self.tap { |proxy| block.call(proxy) if block }
    end

    def method_missing(callback, *args, &block)
      begin
        super
      rescue NoMethodError
        raise "wrong number of arguments (#{args.size} for 0)" unless args.blank?

        callbacks[callback] = (callbacks[callback] || []) + [block] if block

        return self
      end
    end

    def execute_callback(callback, *args)
      callbacks[callback].map { |c| c.call(*args) } if callbacks.has_key?(callback)
    end


    protected

    def callbacks
      @callbacks ||= {}
    end
  end
end