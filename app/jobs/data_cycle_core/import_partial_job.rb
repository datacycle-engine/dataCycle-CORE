# frozen_string_literal: true

module DataCycleCore
  class ImportPartialJob < ImportJob
    def delayed_reference_type
      "import_#{arguments[1]}"
    end

    def perform(uuid, import_name, mode = nil)
      super(uuid) do |external_system|
        options = {}
        options[:mode] = mode if mode.present?
        external_system.import_single(import_name, options)
      end
    end
  end
end
