# frozen_string_literal: true

module DataCycleCore
  class ContentCollectionLinkHistory < ApplicationRecord
    belongs_to :thing_history, touch: true
    belongs_to :collection, polymorphic: true
  end
end
