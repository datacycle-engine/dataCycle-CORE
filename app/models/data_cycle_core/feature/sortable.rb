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

        def default(key, value, user)
          return unless value
          [
            {
              label: I18n.t("sortable.#{key.parameterize(separator: '_')}", default: key, locale: user.ui_locale),
              "method": key
            }
          ]
        end
      end
    end
  end
end
