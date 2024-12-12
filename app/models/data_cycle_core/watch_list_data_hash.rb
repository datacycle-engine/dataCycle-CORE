# frozen_string_literal: true

module DataCycleCore
  class WatchListDataHash < ApplicationRecord
    belongs_to :watch_list, touch: true
    belongs_to :thing
  end
end
