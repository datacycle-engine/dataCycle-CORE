# frozen_string_literal: true

module DataCycleCore
  class DownloadFullJob < ImportJob
    REFERENCE_TYPE = 'download_full'

    def perform(uuid)
      super(uuid) do |external_system|
        external_system.download({ mode: 'full' })
      end
    end
  end
end
