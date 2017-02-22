module DataSetter

  def set_data(data)
    self.attributes.keys.each do |key|
      self.method(key+'=').call(data[key]) if data.has_key?(key)
    end
    return self
  end

end
