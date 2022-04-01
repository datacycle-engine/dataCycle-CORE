# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

((content.untranslatable_property_names & content.plain_property_names) - options[:hidden_attributes]).each do |key|
  json.set! key.camelize(:lower), content.send(key) if content.send(key).present? || content.send(key).is_a?(FalseClass)
end
