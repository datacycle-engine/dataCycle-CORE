module DataCycleCore
  class WatchList < ApplicationRecord
    validates :headline, presence: true
    # associations
    has_many :watch_list_data_hashes, dependent: :destroy
    
    belongs_to :user

  end
end
