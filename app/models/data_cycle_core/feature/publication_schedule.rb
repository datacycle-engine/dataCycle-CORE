# frozen_string_literal: true

module DataCycleCore
  module Feature
    class PublicationSchedule < Base
      class << self
        def available?(content = nil)
          enabled? && attribute_keys(content).present?
        end
      end
    end
  end
end
