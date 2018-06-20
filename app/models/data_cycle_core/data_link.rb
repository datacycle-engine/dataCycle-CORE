# frozen_string_literal: true

module DataCycleCore
  class DataLink < ApplicationRecord
    after_commit :set_release_status, on: [:create, :update], if: -> { permissions == 'write' }

    belongs_to :item, polymorphic: true
    belongs_to :data_link_content_item, foreign_key: 'data_link_id'

    belongs_to :creator, class_name: :User
    belongs_to :receiver, class_name: :User

    belongs_to :text_file, foreign_key: :asset_id

    scope :session_edit_links, ->(ids) { where(permissions: 'write', id: ids) }

    def self.by_creator(creator)
      creator = DataCycleCore::User.find(creator) unless creator.is_a?(DataCycleCore::User)

      where(creator: creator)
    end

    def self.by_receiver(receiver)
      receiver = DataCycleCore::User.find(receiver) unless receiver.is_a?(DataCycleCore::User)

      where(receiver: receiver)
    end

    def self.valid
      where('(data_links.valid_from IS NULL OR data_links.valid_from <= :d) AND (data_links.valid_until IS NULL OR data_links.valid_until >= :d)', d: Time.zone.now.round)
    end

    def self.writable
      where(permissions: 'write')
    end

    def is_valid?
      !valid_from.presence&.>(Time.zone.now.round) && !valid_until.presence&.<(Time.zone.now.round)
    end

    private

    def set_release_status
      creator.subscriptions.find_or_create_by(subscribable_id: item.id, subscribable_type: item.class.name) if item.is_a?(DataCycleCore::Content)

      release_id = DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner])&.id if DataCycleCore.release_codes.present?

      if item.is_a?(DataCycleCore::Content) && DataCycleCore::Feature::Releasable.allowed?(item) && release_id.present? && item.release_id != release_id
        I18n.with_locale(item.first_available_locale) do
          item.update(release_id: release_id)
        end
      elsif item.is_a?(DataCycleCore::WatchList) && release_id.present?
        item.watch_list_data_hashes.includes(:hashable).map(&:hashable).each do |content|
          next unless DataCycleCore::Feature::Releasable.allowed?(content) && content.release_id != release_id

          I18n.with_locale(content.first_available_locale) do
            content.update(release_id: release_id)
          end
        end
      end
    end
  end
end
