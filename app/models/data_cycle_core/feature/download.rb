# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Download < Base
      class << self
        def allowed?(content = nil)
          enabled? && configuration(content).dig('allowed') && DataCycleCore::Feature::Download.dependencies_allowed?(content) && DataCycleCore::Feature::Serialize.available_serializers(content).size.positive?
        end

        def collection_enabled?(type)
          enabled? && configuration.dig('collections', type, 'enabled')
        end

        def collection_serializer_enabled?(type)
          enabled? && collection_enabled?(type) && enabled_collection_serializers(type).size.positive?
        end

        def enabled_collection_serializers(type)
          configuration.dig('collections', type, 'serializers').select { |_, v| v.present? }
        end

        def available_collection_serializers(type)
          enabled_serializers = DataCycleCore::Feature::Serialize.enabled_serializers
          enabled_collection_serializers(type).select { |k, _| enabled_serializers.dig(k) }
        end

        def valid_collection_format?(collection_name, serialize_format)
          (
            collection_enabled?(collection_name) &&
            DataCycleCore::Feature::Serialize.enabled_serializer?(serialize_format)
          )
        end
      end
    end
  end
end
