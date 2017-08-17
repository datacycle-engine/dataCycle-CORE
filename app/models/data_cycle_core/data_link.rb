module DataCycleCore
  class DataLink < ApplicationRecord

    belongs_to :item, polymorphic: true

    belongs_to :creator, class_name: :User

    scope :show_links, -> { where(permissions: "read") }
    scope :edit_links, -> { where(permissions: "write") }
    scope :session_edit_links, -> (ids) { where(permissions: "write", id: ids) }

  end
end
