# frozen_string_literal: true

module DataCycleCore
  class Embedding < ApplicationRecord
    has_neighbors :embedding

    belongs_to :thing, inverse_of: :embeddings
    belongs_to :external_system, inverse_of: :embeddings
  end
end
