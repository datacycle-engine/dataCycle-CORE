# frozen_string_literal: true

module DataCycleCore
  class ThingDuplicate < ApplicationRecord
    belongs_to :original, class_name: 'DataCycleCore::Thing', foreign_key: :thing_id, inverse_of: :thing_originals
    belongs_to :duplicate, class_name: 'DataCycleCore::Thing', foreign_key: :thing_duplicate_id, inverse_of: :thing_duplicates
  end
end
