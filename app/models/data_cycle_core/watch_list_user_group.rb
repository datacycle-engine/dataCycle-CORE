# frozen_string_literal: true

module DataCycleCore
  class WatchListUserGroup < ApplicationRecord
    belongs_to :user_group
    belongs_to :watch_list, touch: true
  end
end
