# frozen_string_literal: true

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
