# frozen_string_literal: true

module DataCycleCore
  class DataLink < ApplicationRecord
    after_commit :set_release_status, on: [:create, :update], if: -> { permissions == 'write' }

    belongs_to :item, polymorphic: true

    belongs_to :creator, class_name: :User
    belongs_to :receiver, class_name: :User

    scope :session_edit_links, ->(ids) { where(permissions: 'write', id: ids) }

    def is_valid?
      (valid_from.nil? || Time.zone.now > valid_from) && (valid_until.nil? || Time.zone.now < valid_until)
    end

    private

    def set_release_status
      creator.subscriptions.create({ subscribable_id: item.id, subscribable_type: item.class }) unless creator.subscriptions.exists?(subscribable_id: item.id, subscribable_type: item.class)

      I18n.with_locale(item.first_available_locale) do
        item.update(release_id: DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner])&.id) if DataCycleCore::Feature::Releasable.allowed?(item) && DataCycleCore.release_codes.present? && DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner]).present?
      end
    end
  end
end
