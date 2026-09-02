# frozen_string_literal: true

# simplecov:disable
module DataCycleCore
  module Api
    module V3
      class StoredFiltersController < ::DataCycleCore::Api::V3::ContentsController
        def show
          index
        end
      end
    end
  end
end
# simplecov:enable
