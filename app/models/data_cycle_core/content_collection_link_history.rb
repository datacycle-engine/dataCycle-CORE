# frozen_string_literal: true

module DataCycleCore
  class ContentCollectionLinkHistory < ApplicationRecord
    belongs_to :thing_history, touch: true, class_name: 'DataCycleCore::Thing::History'
    belongs_to :collection, polymorphic: true
    belongs_to :watch_list
    belongs_to :stored_filter
  end
end
