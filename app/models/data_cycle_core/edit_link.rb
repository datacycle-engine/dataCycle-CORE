module DataCycleCore
  class EditLink < ApplicationRecord

    belongs_to :item, polymorphic: true

    belongs_to :creator, class_name: :User

  end
end
