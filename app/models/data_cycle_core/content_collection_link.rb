# frozen_string_literal: true

module DataCycleCore
  class ContentCollectionLink < ApplicationRecord
    belongs_to :thing, touch: true
    belongs_to :collection, polymorphic: true
    belongs_to :watch_list
    belongs_to :stored_filter
  end
end
