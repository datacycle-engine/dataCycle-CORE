# frozen_string_literal: true

module DataCycleCore
  class GeometryHistory < ApplicationRecord
    belongs_to :thing_history, class_name: 'DataCycleCore::Thing::History', inverse_of: :geometry_histories
  end
end
