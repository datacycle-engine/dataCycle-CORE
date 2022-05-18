# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Download < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::Download
        end

        def allowed?(content, scope = [:content])
          return false unless enabled?
<<<<<<< HEAD
          return false unless DataCycleCore::Feature::Download.dependencies_enabled?
=======
          return false unless dependencies_enabled?
>>>>>>> old/develop
          return false unless configuration.dig(:downloader, *scope, :enabled)
          return false unless configuration.dig(:downloader, *scope, content.class.to_s.demodulize.underscore, :enabled)
          return false unless enabled_serializers_for_download(content, scope).size.positive?

<<<<<<< HEAD
          return configuration(content).dig('allowed') && DataCycleCore::Feature::Download.dependencies_allowed?(content) if content.class.to_s == 'DataCycleCore::Thing' && scope&.first == :content
=======
          return configuration(content).dig('allowed') && dependencies_allowed?(content) if content.class.to_s == 'DataCycleCore::Thing' && scope&.first == :content
>>>>>>> old/develop

          true
        end

        def enabled_serializers_for_download(content, scope = [:content])
          if content.class.to_s == 'DataCycleCore::Thing' && scope&.first == :content
            available_serializers = DataCycleCore::Feature::Serialize.available_serializers(content)
          else
            available_serializers = DataCycleCore::Feature::Serialize.available_serializers
          end
          available_download_serializers = configuration.dig(:downloader, *scope, content.class.to_s.demodulize.underscore, :serializers) || {}
          # archive download inherit serializers from downloader.content.thing.serializers
          available_download_serializers = (configuration.dig(:downloader, :content, :thing, :serializers) || {}).merge(available_download_serializers) if scope&.first != :content
          available_download_serializers.select { |k, v| v.present? && available_serializers.dig(k).present? }
        end

        def enabled_serializers_for_download?(content, scope, serializers)
          serializers.each do |serializer|
            return false unless enabled_serializer_for_download?(content, scope, serializer)
          end
          true
        end

        def enabled_serializer_for_download?(content, scope, serializer)
          enabled_serializers_for_download(content, scope)&.dig(serializer).present?
        end

        def mandatory_serializers_for_download(content, scope)
          return [] unless allowed?(content, scope)
          available_serializers = DataCycleCore::Feature::Serialize.available_serializers
          configuration
            .dig(:downloader, *scope, content.class.to_s.demodulize.underscore, :mandatory_serializers)
            &.select { |k, v| v.present? && available_serializers.dig(k).present? } || {}
        end
<<<<<<< HEAD
=======

        def confirmation_required?(content = nil)
          configuration(content).dig('confirmation', 'required').to_s == 'true'
        end
>>>>>>> old/develop
      end
    end
  end
end
