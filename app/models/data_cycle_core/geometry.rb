# frozen_string_literal: true

module DataCycleCore
  class Geometry < ApplicationRecord
    belongs_to :thing, inverse_of: :geometries
  end
end
