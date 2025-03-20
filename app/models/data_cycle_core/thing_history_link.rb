# frozen_string_literal: true

module DataCycleCore
  class ThingHistoryLink < ApplicationRecord
    self.table_name = 'thing_history_links'
    belongs_to :thing, class_name: 'DataCycleCore::Thing', inverse_of: :thing_history_links
    belongs_to :thing_history, class_name: 'DataCycleCore::Thing::History', inverse_of: :thing_history_links

    has_many :histories, class_name: 'DataCycleCore::ThingHistoryLink::History', inverse_of: :thing_history_link, dependent: :destroy

    class History < ApplicationRecord
      self.table_name = 'thing_history_link_histories'

      belongs_to :thing_history_link, inverse_of: :histories
    end
  end
end
