# frozen_string_literal: true

module DataCycleCore
  class ContentMetaItem < ApplicationRecord
    belongs_to :content, polymorphic: true, foreign_key: :id

    def readonly?
      true
    end
  end
end
