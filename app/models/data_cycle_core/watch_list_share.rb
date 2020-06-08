# frozen_string_literal: true

module DataCycleCore
  class WatchListShare < ApplicationRecord
    belongs_to :watch_list, touch: true
    belongs_to :shareable, polymorphic: true
  end
end
