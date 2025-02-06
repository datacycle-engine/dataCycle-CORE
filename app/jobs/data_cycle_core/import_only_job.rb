# frozen_string_literal: true

module DataCycleCore
  class ImportOnlyJob < ImportJob
    REFERENCE_TYPE = 'import'

    def perform(uuid, mode = nil)
      super do |external_system|
        external_system.import({ mode: mode.presence }.compact)
      end
    end
  end
end
