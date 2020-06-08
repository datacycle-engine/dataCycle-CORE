# frozen_string_literal: true

module DataCycleCore
  module Feature
    class MainFilter < Base
      class << self
        def available_filters
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym, :classification_alias_ids) || []
        end

        def autoload_last_filter?
          configuration.dig('autoload_last_filter')
        end
      end
    end
  end
end
