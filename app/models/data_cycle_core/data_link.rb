module DataCycleCore
  class DataLink < ApplicationRecord
    after_save :set_release_status, if: -> { self.permissions == "write" }

    belongs_to :item, polymorphic: true

    belongs_to :creator, class_name: :User
    belongs_to :receiver, class_name: :User

    scope :session_edit_links, -> (ids) { where(permissions: "write", id: ids) }

    def is_valid?
      (valid_from.nil? || DateTime.now > valid_from) && (valid_until.nil? || DateTime.now < valid_until)
    end

    private
    def set_release_status
      unless self.creator.subscriptions.exists?(subscribable_id: self.item.id, subscribable_type: self.item.class)
        self.creator.subscriptions.create({subscribable_id: self.item.id, subscribable_type: self.item.class})
      end

      if self.item.metadata.dig('validation', 'releasable')
        self.item.update_attribute(:release_id, DataCycleCore::Release.where(release_code: 1).try(:first).try(:id))
      end
    end

  end
end
