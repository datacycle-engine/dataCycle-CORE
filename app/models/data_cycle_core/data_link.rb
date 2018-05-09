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
      where('(valid_from IS NULL OR valid_from <= :d) AND (valid_until IS NULL OR valid_until >= :d)', d: DateTime.now)
    end

    def is_valid?
      !valid_from.presence&.>(DateTime.now) && !valid_until.presence&.<(DateTime.now)
    end

    private

    def set_release_status
      creator.subscriptions.find_or_create_by(subscribable_id: item.id, subscribable_type: item.class) if DataCycleCore.content_tables.include?(item.class.table_name)

      if item.try(:schema)&.dig('releasable') && DataCycleCore.release_codes.present? && DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner]).present?
        I18n.with_locale(item.first_available_locale) do
          item.update(release_id: DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner])&.id)
        end
      elsif item.is_a?(DataCycleCore::WatchList)
        release_id = DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner])&.id
        item.watch_list_data_hashes.includes(:hashable).map(&:hashable).each do |content|
          I18n.with_locale(content.first_available_locale) do
            content.update(release_id: release_id) if content.try(:schema)&.dig('releasable') && content.release_id != release_id
          end
        end
      end
    end
  end
end
