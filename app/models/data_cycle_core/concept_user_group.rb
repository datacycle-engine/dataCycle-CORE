# frozen_string_literal: true

module DataCycleCore
  class ConceptUserGroup < ApplicationRecord
    belongs_to :concept
    belongs_to :user_group
  end
end
