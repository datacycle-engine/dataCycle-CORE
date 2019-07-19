# frozen_string_literal: true

module DataCycleCore
  class Event < ApplicationRecord
    belongs_to :user
    belongs_to :eventable, polymorphic: true
  end
end
