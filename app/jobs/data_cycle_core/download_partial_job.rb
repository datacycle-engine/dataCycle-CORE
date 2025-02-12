# frozen_string_literal: true

module DataCycleCore
  class DownloadPartialJob < ImportJob
    REFERENCE_TYPE = 'download'

    def perform(uuid, download_name, mode = nil)
      super(uuid) do |external_system|
        options = {}
        options[:mode] = mode if mode.present?
        external_system.download_single(download_name, options)
      end
    end
  end
end
