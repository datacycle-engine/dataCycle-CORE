# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Sortable < Base
      class << self
        def available_options
          sortable = []
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym)&.except(:enabled)&.each do |key, value|
            sortable.concat(try(key.to_sym, value) || default(key.to_s, value) || [])
          end
          sortable
        end

        def default(key, value)
          return unless value
          [
            {
              label: I18n.t("sortable.#{key.parameterize(separator: '_')}", default: key, locale: DataCycleCore.ui_language),
              "method": key
            }
          ]
        end
      end
    end
  end
end
