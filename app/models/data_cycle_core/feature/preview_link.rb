# frozen_string_literal: true

module DataCycleCore
  module Feature
    class PreviewLink < Base
      class << self
        def allowed?(content = nil)
          super && configuration(content)['module'].present? && configuration(content)['method'].present?
        end

        def build(content, locale)
          preview_link_builder = configuration(content)[:module]&.safe_constantize
          builder_methode = configuration(content)[:method]
          return if preview_link_builder.blank?

          preview_link_builder.send(builder_methode, content, locale)
        end
      end
    end
  end
end
