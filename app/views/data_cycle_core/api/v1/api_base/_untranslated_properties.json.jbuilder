default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

((content.untranslatable_property_names & content.plain_property_names) - options[:hidden_attributes]).each do |key|
  unless content.send(key).blank?
    json.set! key.camelize(:lower), content.send(key)
  end
end
