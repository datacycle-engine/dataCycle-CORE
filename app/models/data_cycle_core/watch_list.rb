module DataCycleCore
  class WatchList < ApplicationRecord
    # associations
    has_many :watch_list_data_hashes, dependent: :destroy
    
    belongs_to :user

  end
end
