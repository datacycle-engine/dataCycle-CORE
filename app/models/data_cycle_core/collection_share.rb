# frozen_string_literal: true

module DataCycleCore
  class CollectionShare < ApplicationRecord
    belongs_to :collection, touch: true
    belongs_to :shareable, polymorphic: true
  end
end
