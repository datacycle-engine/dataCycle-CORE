# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Serialize < Base
      class << self
        def available_serializers(content = nil)
          configuration(content).dig('serializers').select { |k, _| enabled_serializers.dig(k) }
        end

        def available_serializer?(content, serializer)
          available_serializers(content).dig(serializer).present?
        end

        def enabled_serializers
          configuration.dig('serializers').select { |_, v| v.present? }
        end

        def enabled_serializer?(serializer)
          serializer&.each do |format|
            return true if enabled_serializers.dig(format)
          end
          false
        end

        def asset_versions(content = nil)
          configuration(content).dig('serializers', 'asset').is_a?(Hash) ? configuration(content).dig('serializers', 'asset') : {}
        end
      end
    end
  end
end
