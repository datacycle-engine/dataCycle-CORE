# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module Download
        def download_content(**options)
          download_data(->(data) { data['url'] }, ->(data) { data['headline'] }, options)
        end
      end
    end
  end
end
