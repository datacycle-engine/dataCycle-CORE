# frozen_string_literal: true

# simplecov:disable
module DataCycleCore
  module Api
    module V2
      class StoredFiltersController < Api::V2::ContentsController
        def show
          index
        end
      end
    end
  end
end
# simplecov:enable
