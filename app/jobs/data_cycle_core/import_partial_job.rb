# frozen_string_literal: true

module DataCycleCore
  class ImportPartialJob < ImportJob
    REFERENCE_TYPE = 'import'

    def perform(uuid, import_name, mode = nil)
      super(uuid) do |external_system|
        options = {}
        options[:mode] = mode if mode.present?
        external_system.import_single(import_name, options)
      end
    end
  end
end
