module DataCycleCore
  class ClassificationContent < ApplicationRecord

    include DataSetter

    belongs_to :content_data, polymorphic: true
    belongs_to :classification

    class History < ApplicationRecord
      belongs_to :content_data_history, polymorphic: true
      belongs_to :classification
    end

  end
end