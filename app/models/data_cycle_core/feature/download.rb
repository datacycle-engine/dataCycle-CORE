# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Download < Base
      class << self
        def allowed?(content, download_scopes = [:content])
          return false unless enabled?
          return false unless dependencies_enabled?
          return false unless configuration.dig(:downloader, *download_scopes, :enabled)
          return false unless configuration.dig(:downloader, *download_scopes, content&.model_name&.param_key, :enabled)
          return false unless enabled_serializers_for_download(content, download_scopes).size.positive?

          return configuration(content).dig('allowed') && dependencies_allowed?(content) if content.instance_of?(::DataCycleCore::Thing) && download_scopes&.first == :content

          true
        end

        def enabled_serializers_for_download(content, download_scopes = [:content])
          if content.instance_of?(::DataCycleCore::Thing) && download_scopes&.first == :content
            available_serializers = DataCycleCore::Feature::Serialize.available_serializers(content)
          else
            available_serializers = DataCycleCore::Feature::Serialize.available_serializers
          end

          available_download_serializers = configuration.dig(:downloader, *download_scopes, content&.model_name&.param_key, :serializers) || {}
          # archive download inherit serializers from downloader.content.thing.serializers
          available_download_serializers = (configuration.dig(:downloader, :content, :thing, :serializers) || {}).merge(available_download_serializers) if download_scopes&.first != :content
          available_download_serializers.select { |k, v| v.present? && available_serializers.dig(k).present? }
        end

        def enabled_serializers_for_download?(content, download_scopes, serializers)
          serializers.each do |serializer|
            return false unless enabled_serializer_for_download?(content, download_scopes, serializer)
          end

          true
        end

        def enabled_serializer_for_download?(content, download_scopes, serializer)
          enabled_serializers_for_download(content, download_scopes)&.dig(serializer).present?
        end

        def mandatory_serializers_for_download(content, download_scopes)
          return [] unless allowed?(content, download_scopes)
          available_serializers = DataCycleCore::Feature::Serialize.available_serializers
          configuration
            .dig(:downloader, *download_scopes, content&.model_name&.param_key, :mandatory_serializers)
            &.select { |k, v| v.present? && available_serializers.dig(k).present? } || {}
        end

        def confirmation_required?(content = nil)
          configuration(content).dig('confirmation', 'required').to_s == 'true'
        end
      end
    end
  end
end
