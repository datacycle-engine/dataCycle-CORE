# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Serialize < Base
      class << self
        def available_serializers(content = nil)
          configuration(content).dig('serializers').select { |k, _v| enabled_serializers.dig(k) }
        end

        def allowed_serializer?(content, serializer)
          available_serializers(content)&.dig(serializer)
        end

        def enabled_serializers
          configuration.dig('serializers').select { |_, v| v.present? }
        end
      end
    end
  end
end
