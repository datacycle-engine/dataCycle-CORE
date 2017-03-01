module DataCycleCore
  module DataSetter

    def set_data(data)
      self.attributes.keys.each do |key|
        # be agnostic for symbols or strings
        self.method(key+'=').call(data[key]) if data.has_key?(key)
        self.method(key+'=').call(data[key.to_sym]) if data.has_key?(key.to_sym)
      end
      return self
    end

  end
end
