# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class StoredFiltersController < ::DataCycleCore::Api::V4::ContentsController
        def show
          index
        end
      end
    end
  end
end
