# frozen_string_literal: true

module DataCycleCore
  class EmbeddingHistory < ApplicationRecord
    has_neighbors :embedding

    belongs_to :thing_history, class_name: 'DataCycleCore::Thing::History', inverse_of: :embedding_histories
    belongs_to :external_system, inverse_of: :embedding_histories
  end
end
