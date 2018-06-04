# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Download
        def download_content(**options)
          download_data(->(data) { data['id'] }, ->(data) { data['name'] }, options)
        end
      end
    end
  end
end
