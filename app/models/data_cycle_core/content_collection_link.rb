# frozen_string_literal: true

module DataCycleCore
  class ContentCollectionLink < ApplicationRecord
    belongs_to :thing
    belongs_to :collection
  end
end
