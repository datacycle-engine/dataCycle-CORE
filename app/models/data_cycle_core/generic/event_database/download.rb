# frozen_string_literal: true

module DataCycleCore
  module Generic
    module EventDatabase
      module Download
        def download_content(**options)
          download_data(->(data) { data['url'] }, ->(data) { data['name'] }, options)
        end
      end
    end
  end
end
