# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Extensions
        module Tooltip
          def to_tooltip(_content, definition, locale)
            tooltip_base_string(definition.dig('content_score', 'method'), locale: locale)
          end

          def tooltip_base_string(path, **params)
            tooltip = tooltip_string(path, **params)

            I18n.t('feature.content_score.tooltip.criteria', text: tooltip, locale: params[:locale]) if tooltip.present?
          end

          def tooltip_string(path, **params)
            if I18n.exists?("feature.content_score.tooltip.#{name.demodulize.underscore}.#{path}", **params)
              I18n.t("feature.content_score.tooltip.#{name.demodulize.underscore}.#{path}", **params)
            elsif I18n.exists?("feature.content_score.tooltip.#{path}", **params)
              I18n.t("feature.content_score.tooltip.#{path}", **params)
            end
          end
        end
      end
    end
  end
end
