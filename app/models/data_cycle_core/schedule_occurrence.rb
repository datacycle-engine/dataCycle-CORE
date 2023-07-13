# frozen_string_literal: true

module DataCycleCore
  class ScheduleOccurrence < ApplicationRecord
    belongs_to :schedule
    belongs_to :thing
  end
end
