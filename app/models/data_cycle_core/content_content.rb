module DataCycleCore
  class ContentContent < ApplicationRecord
    include DataSetter

    belongs_to :content_a, polymorphic: true
    belongs_to :content_b, polymorphic: true

    class History < ApplicationRecord
      belongs_to :content_a_history, polymorphic: true #, class_name: "DataCycleCore::CreativeWork::History"
      belongs_to :content_b_history, polymorphic: true #, class_name: "DataCycleCore::Person::History"
    end
  end
end
