# frozen_string_literal: true

module DataCycleCore
  module Feature
    class MainFilter < Base
      class << self
        def available_filters(view:, user:)
          configuration.dig(:config, "#{view}_view").filter { |k, v| v.present? && user.can?(k, view, v) }
        end

        def autoload_last_filter?
          configuration.dig('autoload_last_filter')
        end
      end
    end
  end
end
