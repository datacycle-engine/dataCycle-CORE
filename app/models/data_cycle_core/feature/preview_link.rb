# frozen_string_literal: true

module DataCycleCore
  module Feature
    class PreviewLink < Base
      def self.allowed?(content = nil)
        return false if content.blank?
        enabled? && configuration(content)['allowed'] && configuration(content)['module'].present? && configuration(content)['method'].present?
      end

      def self.build(content, locale)
        preview_link_builder = DataCycleCore.features.dig(:preview_link, :module)&.safe_constantize
        builder_methode = DataCycleCore.features.dig(:preview_link, :method)
        return nil unless preview_link_builder.present?

        preview_link_builder.send(builder_methode, content, locale)
      end
    end
  end
end
