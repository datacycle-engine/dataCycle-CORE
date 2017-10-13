module DataCycleCore
  class Search < ApplicationRecord
    belongs_to :content_data, polymorphic: true
  end
end
