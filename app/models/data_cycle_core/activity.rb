# frozen_string_literal: true

module DataCycleCore
  class Activity < ApplicationRecord
    belongs_to :user
    belongs_to :activitiable, polymorphic: true
  end
end
