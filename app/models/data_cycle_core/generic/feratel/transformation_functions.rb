module DataCycleCore::Generic::Feratel::TransformationFunctions
  extend Transproc::Registry
  import Transproc::HashTransformations
  import Transproc::Conditional
  import Transproc::Recursion
  import DataCycleCore::Generic::Transformations::Functions

  def self.flatten_translations(data)
    raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

    return data.map { |v| flatten_translations(v) } if data.is_a?(Array)

    Hash[data.map do |k, v|
      if k == 'Translation'
        ['text', v['text']]
      elsif v.is_a?(Hash) || v.is_a?(Array)
        [k, flatten_translations(v)]
      else
        [k, v]
      end
    end]
  end

  def self.flatten_texts(data)
    raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

    return data.map { |v| flatten_texts(v) } if data.is_a?(Array)

    Hash[data.map do |k, v|
      if v.is_a?(Hash) && v.keys == ['text']
        [k, v['text']]
      elsif v.is_a?(Hash) || v.is_a?(Array)
        [k, flatten_texts(v)]
      else
        [k, v]
      end
    end]
  end

  def self.unwrap_description(data, description_type)
    raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

    return data.map { |v| unwrap_description(v, description_type) } if data.is_a?(Array)

    Hash[data.map do |k, v|
      if k == 'Descriptions'
        [
          description_type,
          [v['Description']].flatten.select do |h|
            h['Type'] == description_type
          end.first.try(:[], 'text')
        ]
      else
        [k, v]
      end
    end]
  end

  def self.unwrap_address(data, address_type)
    raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

    return data.map { |v| unwrap_address(v, address_type) } if data.is_a?(Array)

    Hash[data.map do |k, v|
      if k == 'Addresses'
        [
          'Address',
          [v['Address']].flatten.select do |h|
            h['Type'] == address_type
          end.first
        ]
      elsif v.is_a?(Hash) || v.is_a?(Array)
        [k, unwrap_address(v, address_type)]
      else
        [k, v]
      end
    end]
  end
end
