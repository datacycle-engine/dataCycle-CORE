# frozen_string_literal: true

module DataCycleCore
  class DownloadJob < ImportJob
    REFERENCE_TYPE = 'download'

    def perform(uuid)
      super(uuid, &:download)
    end
  end
end
