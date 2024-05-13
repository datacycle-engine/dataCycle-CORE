# frozen_string_literal: true

module DataCycleCore
  class ContentCollectionLinkHistory < ApplicationRecord
    belongs_to :thing_history, class_name: 'DataCycleCore::Thing::History'
    belongs_to :collection
  end
end
