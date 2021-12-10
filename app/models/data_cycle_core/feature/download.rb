# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Download < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::Download
        end

        def allowed?(content)
          return false unless enabled?
          return false unless DataCycleCore::Feature::Download.dependencies_enabled?
          return false unless configuration.dig(:content, content.class.to_s.demodulize.underscore, :enabled)
          return false unless enabled_serializers_for_download(content).size.positive?

          return configuration(content).dig('allowed') && DataCycleCore::Feature::Download.dependencies_allowed?(content) if content.class.to_s == 'DataCycleCore::Thing'

          true
        end

        def enabled_serializers_for_download(content)
          if content.class.to_s == 'DataCycleCore::Thing'
            available_serializers = DataCycleCore::Feature::Serialize.available_serializers(content)
          else
            available_serializers = DataCycleCore::Feature::Serialize.available_serializers
          end

          available_download_serializers = configuration.dig(:content, content.class.to_s.demodulize.underscore, :serializers)
          available_download_serializers.select { |k, v| v.present? && available_serializers.dig(k).present? }
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

        def valid_collection_serializer_format?(collection_name, serialize_format)
          (
            collection_serializer_enabled?(collection_name) &&
            available_collection_serializers(collection_name)&.dig(serialize_format)&.present?
          )
        end
      end
    end
  end
end
