# frozen_string_literal: true

module VirtualAttributeTestUtilities
  def create_content_dummy(data)
    if data.is_a?(Array)
      data.map { |d| create_content_dummy(d) }
    elsif data.is_a?(Hash)
      Struct.new(*data.keys).new(*data.values.map { |d| create_content_dummy(d) })
    else
      data
    end
  end
end
