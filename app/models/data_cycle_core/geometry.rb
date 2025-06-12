# frozen_string_literal: true

module DataCycleCore
  class Geometry < ApplicationRecord
    attr_readonly :is_primary, :geom_simple

    belongs_to :thing, inverse_of: :geometries

    scope :primary, -> { where(is_primary: true) }
  end
end
