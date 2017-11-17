module DataCycleCore
  class ContentContent < ApplicationRecord
    include DataSetter

    belongs_to :content_a, polymorphic: true
    belongs_to :content_b, polymorphic: true

    class History < ApplicationRecord
      belongs_to :content_a_history, polymorphic: true
      belongs_to :content_b_history, polymorphic: true 
    end
  end
end
