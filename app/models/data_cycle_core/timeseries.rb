# frozen_string_literal: true

module DataCycleCore
  class Timeseries < ApplicationRecord
    self.primary_key = :thing_id
    belongs_to :thing, class_name: 'DataCycleCore::Thing'

    after_save { |item| item.thing.touch }
  end
end
