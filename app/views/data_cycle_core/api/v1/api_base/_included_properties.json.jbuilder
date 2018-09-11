# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

(content.included_property_names - options[:hidden_attributes]).each do |key|
  next if content.send(key).blank?
  json.set! key.camelize(:lower) do
    content.send(key).to_h.each do |d|
      json.set! d[0], d[1]
    end
  end
end
