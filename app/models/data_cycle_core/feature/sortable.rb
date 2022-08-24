# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Sortable < Base
      class << self
        def available_options(user, view)
          return [] unless enabled?

          sortable = []
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym)&.except(:enabled)&.each do |key, value|
            sortable.concat(try(key.to_sym, value, user) || default(key.to_s, value, user) || [])
          end
          sortable.select { |k, v| user.can?(:sortable, view.to_sym, k, v) }
        end

        def available_advanced_attribute_options
          return {} unless enabled?
          configuration.dig('advanced_attributes') || {}
        end

        def default(key, value, user)
          return unless value
          [
            {
              label: I18n.t("sortable.#{key.parameterize(separator: '_')}", default: key, locale: user.ui_locale),
              "method": key
            }
          ]
        end

        def advanced_attributes(value, user)
          return [] unless value
          value.map do |k, _v|
            {
              label: I18n.t("sortable.#{k.parameterize(separator: '_')}", default: k, locale: user.ui_locale),
              "method": "advanced_attribute_#{k}"
            }
          end
        end
      end
    end
  end
end
