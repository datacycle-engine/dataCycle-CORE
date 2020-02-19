# frozen_string_literal: true

module DataCycleCore
  class FeatureService
    def self.collect_features(definition)
      features = definition&.dig('features') || {}
      definition&.dig('properties')&.each_value do |v|
        if v&.key?('properties')
          features.merge(collect_features(v))
        elsif v&.key?('features')
          features.merge(v['features'])
        end
      end
      features
    end

    def self.enabled_features(definition, key = nil)
      collected_features = DataCycleCore::FeatureService.collect_features(definition)
      enabled_feature_keys = DataCycleCore.features.select { |_, v| v[:enabled] }.keys.map(&:to_s) & collected_features.keys

      return enabled_feature_keys if key.blank?

      DataCycleCore.features.with_indifferent_access.merge(collected_features).slice(enabled_feature_keys).select { |_, v| v.is_a?(Hash) && v[:attribute_keys].presence&.include?(key) }.keys.map(&:to_s)
    end
  end
end
