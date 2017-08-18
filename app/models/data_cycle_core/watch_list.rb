module DataCycleCore
  class WatchList < ApplicationRecord
    validates :headline, presence: true

    has_many :watch_list_data_hashes, dependent: :destroy
    belongs_to :user

    has_one :show_link, -> { DataLink.show_links }, class_name: "DataLink", as: :item

  end
end
