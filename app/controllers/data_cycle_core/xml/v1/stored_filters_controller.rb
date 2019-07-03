# frozen_string_literal: true

module DataCycleCore
  module Xml
    module V1
      class StoredFiltersController < ::DataCycleCore::Xml::V1::ContentsController
        def show
          index
        end
      end
    end
  end
end
