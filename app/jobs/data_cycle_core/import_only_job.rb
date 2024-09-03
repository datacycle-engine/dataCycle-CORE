# frozen_string_literal: true

module DataCycleCore
  class ImportOnlyJob < ImportJob
    REFERENCE_TYPE = 'import'

    def perform(uuid)
      super(uuid, &:import)
    end
  end
end
