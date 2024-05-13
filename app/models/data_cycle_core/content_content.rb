# frozen_string_literal: true

module DataCycleCore
  class ContentContent < ApplicationRecord
    belongs_to :content_a, class_name: 'DataCycleCore::Thing'
    belongs_to :content_b, class_name: 'DataCycleCore::Thing'

    class History < ApplicationRecord
      belongs_to :content_a_history, class_name: 'DataCycleCore::Thing::History'
      belongs_to :content_b_history, polymorphic: true
    end

    class Link < ApplicationRecord
      belongs_to :content_a, class_name: 'DataCycleCore::Thing'
      belongs_to :content_b, class_name: 'DataCycleCore::Thing'
      belongs_to :content_content_id, class_name: 'DataCycleCore::ContentContent'
    end
  end
end
