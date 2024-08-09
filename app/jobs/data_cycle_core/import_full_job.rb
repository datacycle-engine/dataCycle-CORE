# frozen_string_literal: true

module DataCycleCore
  class ImportFullJob < ImportJob
    REFERENCE_TYPE = 'import_full'

    def perform(uuid)
      super(uuid) do |external_system|
        external_system.import({ mode: 'full' })
      end
    end
  end
end
