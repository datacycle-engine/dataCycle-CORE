# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ContentLock < Base
      class << self
        def lock_length
          configuration.dig('lock_length')
        end

        def lock_renew_before
          configuration.dig('lock_renew_before')
        end
      end
    end
  end
end
