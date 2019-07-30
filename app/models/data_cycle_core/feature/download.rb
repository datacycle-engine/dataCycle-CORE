# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Download < Base
      class << self
        def allowed?(content = nil)
          enabled? && configuration(content).dig('allowed') && DataCycleCore::Feature::Download.dependencies_allowed?(content) && DataCycleCore::Feature::Serialize.available_serializers(content).size.positive?
        end

        def available_collection_serializers(type)
          enabled_serializers = DataCycleCore::Feature::Serialize.enabled_serializers
          enabled_collection_serializers(type).select { |k, _| enabled_serializers.dig(k) }
        end

        def watchlist_enabled?
          enabled? && configuration.dig('collections', 'watch_list', 'enabled')
        end

        def enabled_collection_serializers(type)
          configuration.dig('collections', type, 'serializers').select { |_, v| v.present? }
        end
      end
    end
  end
end
