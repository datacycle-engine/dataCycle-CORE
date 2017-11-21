module DataCycleCore
  class DataLink < ApplicationRecord

    belongs_to :item, polymorphic: true

    belongs_to :creator, class_name: :User
    belongs_to :receiver, class_name: :User

    scope :session_edit_links, -> (ids) { where(permissions: "write", id: ids) }
  end
end
