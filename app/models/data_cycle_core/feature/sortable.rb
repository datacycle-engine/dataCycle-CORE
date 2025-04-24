# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Sortable < Base
      class << self
        def available_options(user, view)
          return [] unless enabled?

          sortable = []

          (configuration["#{view}_context"].presence || configuration&.reject { |k, _v| k == 'enabled' || k.end_with?('_context') })&.each do |key, value|
            if respond_to?(key) && method(key).parameters.size == 2
              sortable.concat(send(key.to_sym, value, user))
            else
              sortable.concat(default(key.to_s, value, user, view))
            end
          end

          sortable.select { |k, v| user.can?(:sortable, view.to_sym, k, v) }
        end

        def available_advanced_attribute_options
          return {} unless enabled?
          configuration['advanced_attributes'] || {}
        end

        def default(key, value, user, view = 'backend')
          return [] unless value

          [
            {
              label: I18n.t("sortable.#{view}_context.#{key.underscore_blanks}", default: I18n.t("sortable.#{key.underscore_blanks}", default: key, locale: user.ui_locale), locale: user.ui_locale),
              method: key
            }
          ]
        end

        def advanced_attributes(value, user)
          return [] unless value

          value.map do |k, _v|
            {
              label: I18n.t("sortable.#{k.underscore_blanks}", default: k, locale: user.ui_locale),
              method: "advanced_attribute_#{k}"
            }
          end
        end

        def available_advanced_attribute_for_key(key)
          return key if available_advanced_attribute_options[key].present?
          return available_advanced_attribute_options.key(key) if available_advanced_attribute_options.value?(key.to_s)

          nil
        end
      end
    end
  end
end
