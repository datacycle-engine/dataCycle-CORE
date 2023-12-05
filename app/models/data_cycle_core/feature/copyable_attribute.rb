# frozen_string_literal: true

module DataCycleCore
  module Feature
    class CopyableAttribute < Base
      class << self
        def copyable_attribute?(content, key)
          enabled? && includes_attribute_key(content, key)
        end

        def from_attribute(content)
          configuration(content)[:from]
        end

        def clear_from_attribute?(content)
          configuration(content)[:clear_from_attribute] == true
        end

        def from_attribute_label(content)
          content&.properties_for(from_attribute(content))&.dig('label')
        end

        def link_title(content, locale)
          I18n.t('actions.copyable_from', data: from_attribute_label(content), locale:)
        end

        def clear_title(content, locale)
          I18n.t('actions.copyable_from_clear', data: from_attribute_label(content), locale:)
        end
      end
    end
  end
end
