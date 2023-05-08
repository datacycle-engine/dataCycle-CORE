# frozen_string_literal: true

module DataCycleCore
  class ClassificationPolygon < ApplicationRecord
    belongs_to :classification_alias
  end
end
