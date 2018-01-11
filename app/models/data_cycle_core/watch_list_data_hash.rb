module DataCycleCore
  class WatchListDataHash < ApplicationRecord
    belongs_to :watch_list
    belongs_to :hashable, polymorphic: true
  end
end
