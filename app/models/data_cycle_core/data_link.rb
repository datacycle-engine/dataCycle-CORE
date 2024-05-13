# frozen_string_literal: true

module DataCycleCore
  class DataLink < ApplicationRecord
    after_commit :set_release_status, on: [:create, :update], if: -> { permissions == 'write' }

    belongs_to :item, polymorphic: true
    belongs_to :data_link_content_item, foreign_key: 'data_link_id'
    belongs_to :collection, -> { where(data_links: { item_type: 'DataCycleCore::Collection' }) }, foreign_key: :item_id
    belongs_to :watch_list, -> { where(type: 'DataCycleCore::WatchList', data_links: { item_type: 'DataCycleCore::Collection' }) }, foreign_key: :item_id
    belongs_to :stored_filter, -> { where(type: 'DataCycleCore::StoredFilter', data_links: { item_type: 'DataCycleCore::Collection' }) }, foreign_key: :item_id

    belongs_to :creator, class_name: :User
    belongs_to :receiver, class_name: :User

    belongs_to :text_file, foreign_key: :asset_id

    scope :by_creator, ->(creators) { where(creator_id: user_id_from_creators(creators)) }
    scope :by_receiver, ->(receivers) { where(receiver_id: user_id_from_creators(receivers)) }
    scope :valid, -> { where('(data_links.valid_from IS NULL OR data_links.valid_from <= :d) AND (data_links.valid_until IS NULL OR data_links.valid_until >= :d)', d: Time.zone.now.round) }
    scope :readable, -> { where(permissions: ['read', 'write']) }
    scope :writable, -> { where(permissions: 'write') }
    scope :thing_links, -> { where(item_type: 'DataCycleCore::Thing') }

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
      now = Time.zone.now.round
      (valid_from.nil? || valid_from <= now) && (valid_until.nil? || valid_until >= now)
    end

    def self.valid_stored_filters
      return DataCycleCore::StoredFilter.none if all.is_a?(ActiveRecord::NullRelation)

      DataCycleCore::StoredFilter.where(id: where(item_type: 'DataCycleCore::Collection').valid.pluck(:item_id))
    end

    def self.user_id_from_creators(users)
      case users
      when ActiveRecord::Relation
        users.select(:id)
      when ActiveRecord::Base
        users.id
      else
        Array.wrap(users)
      end
    end

    private

    def set_release_status
      creator.subscriptions.find_or_create_by(subscribable_id: item.id, subscribable_type: item.class.name) if item.is_a?(DataCycleCore::Thing) && creator != receiver

      release_partner_stage_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('partner'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } })&.id

      if item.is_a?(DataCycleCore::Thing) && DataCycleCore::Feature::Releasable.allowed?(item) && release_partner_stage_id.present? && !item.release_status_id&.ids&.include?(release_partner_stage_id)
        I18n.with_locale(item.first_available_locale) do
          item.set_data_hash(data_hash: { DataCycleCore::Feature::Releasable.allowed_attribute_keys(item).first => [release_partner_stage_id] }, current_user: creator)
        end
      elsif item.is_a?(DataCycleCore::WatchList) && release_partner_stage_id.present?
        item.things.includes(:classification_aliases, :translations).find_each do |content|
          next unless DataCycleCore::Feature::Releasable.allowed?(content) && !content.release_status_id&.ids&.include?(release_partner_stage_id)

          I18n.with_locale(content.first_available_locale) do
            content.set_data_hash(data_hash: { DataCycleCore::Feature::Releasable.allowed_attribute_keys(content).first => [release_partner_stage_id] }, current_user: creator)
          end
        end
      end
    end
  end
end
