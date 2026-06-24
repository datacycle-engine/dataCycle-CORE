# frozen_string_literal: true

module DataCycleCore
  class StoredFilterCache < ApplicationRecord
    belongs_to :stored_filter, class_name: 'DataCycleCore::StoredFilter', inverse_of: :stored_filter_caches
    belongs_to :thing, class_name: 'DataCycleCore::Thing', inverse_of: :stored_filter_caches
  end
end
