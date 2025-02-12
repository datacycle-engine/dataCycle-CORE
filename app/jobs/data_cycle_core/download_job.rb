# frozen_string_literal: true

module DataCycleCore
  class DownloadJob < ImportJob
    REFERENCE_TYPE = 'download'

    def perform(uuid, mode = nil)
      super do |external_system|
        external_system.download({ mode: mode.presence }.compact)
      end
    end
  end
end
