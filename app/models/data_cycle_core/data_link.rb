# frozen_string_literal: true

module DataCycleCore
  class DataLink < ApplicationRecord
    after_commit :set_release_status, on: [:create, :update], if: -> { permissions == 'write' }

    belongs_to :item, polymorphic: true
    belongs_to :data_link_content_item, foreign_key: 'data_link_id'

    belongs_to :creator, class_name: :User
    belongs_to :receiver, class_name: :User

    belongs_to :text_file, foreign_key: :asset_id

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

    def writable?
      permissions == 'write'
    end

    def readable?
      permissions == 'read'
    end

    def downloadable?
      permissions == 'download'
    end

    def is_valid?
      !valid_from.presence&.>(Time.zone.now.round) && !valid_until.presence&.<(Time.zone.now.round)
    end

    def self.valid_stored_filters
      DataCycleCore::StoredFilter.where(id: all.where(item_type: 'DataCycleCore::StoredFilter').valid.pluck(:item_id))
    end

    private

    def set_release_status
      creator.subscriptions.find_or_create_by(subscribable_id: item.id, subscribable_type: item.class.name) if item.is_a?(DataCycleCore::Content::Content)

      release_partner_stage_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('partner'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } })&.id

      if item.is_a?(DataCycleCore::Content::Content) && DataCycleCore::Feature::Releasable.allowed?(item) && release_partner_stage_id.present? && !item.release_status_id&.ids&.include?(release_partner_stage_id)
        I18n.with_locale(item.first_available_locale) do
          item.set_data_hash(data_hash: { DataCycleCore::Feature::Releasable.allowed_attribute_keys(item).first => [release_partner_stage_id] }, current_user: creator, partial_update: true)
        end
      elsif item.is_a?(DataCycleCore::WatchList) && release_partner_stage_id.present?
        item.things.includes(:classification_aliases, :translations).find_each do |content|
          next unless DataCycleCore::Feature::Releasable.allowed?(content) && !content.release_status_id&.ids&.include?(release_partner_stage_id)

          I18n.with_locale(content.first_available_locale) do
            content.set_data_hash(data_hash: { DataCycleCore::Feature::Releasable.allowed_attribute_keys(content).first => [release_partner_stage_id] }, current_user: creator, partial_update: true)
          end
        end
      end
    end
  end
end
