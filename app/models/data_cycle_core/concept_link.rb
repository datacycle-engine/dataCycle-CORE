# frozen_string_literal: true

module DataCycleCore
  class ConceptLink < ApplicationRecord
    belongs_to :parent
    belongs_to :child

    # keep readonly until reverse triggers are defined and working
    def readonly?
      true
    end
  end
end
