# frozen_string_literal: true

module DataCycleCore
  class DataLinkContentItem < ApplicationRecord
    self.table_name = 'content_items'

    belongs_to :indirect_data_link, class_name: :DataLink, foreign_key: :data_link_id, inverse_of: :data_link_content_item
    belongs_to :content, polymorphic: true
    belongs_to :creator, class_name: :User, inverse_of: :created_data_links
    belongs_to :receiver, class_name: :User, inverse_of: :received_data_links

    def readonly?
      true
    end
  end
end
