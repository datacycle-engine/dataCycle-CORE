# frozen_string_literal: true

module DataCycleCore
  class CollectionConceptSchemeLink < ApplicationRecord
    belongs_to :collection
    belongs_to :concept_scheme
  end
end
