# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemSync < ApplicationRecord
    belongs_to :syncable, polymorphic: true
    belongs_to :external_system

    DUPLICATE_SYNC_TYPE = 'duplicate'

    def external_url
      return data.dig('external_url') if data&.dig('external_url').present?
      return if !syncable.is_a?(DataCycleCore::Thing) || external_system&.default_options(:export)&.dig('external_url').blank? || external_key.blank?

      format(external_system.default_options(:export).dig('external_url'), locale: I18n.locale, type: type, external_key: external_key)
    end

    def external_detail_url
      return data.dig('external_detail_url') if data&.dig('external_detail_url').present?
      return if !syncable.is_a?(DataCycleCore::Thing) || external_system&.default_options(:export)&.dig('external_detail_url').blank? || external_key.blank?

      format(external_system.default_options(:export).dig('external_detail_url'), locale: I18n.locale, type: type, external_key: external_key)
    end

    def type
      external_system&.default_options(:export)&.dig('type_mapping', syncable.template_name) || syncable.template_name.underscore_blanks
    end

    def external_key
      super || data&.dig(external_system&.default_options(:export)&.dig('external_key_param') || 'external_key')
    end

    def self.with_external_system(external_system_id)
      find_by(external_system_id: external_system_id)
    end

    def self.to_external_data_hash
      all.includes(:external_system)
        .select(:external_system_id, :created_at, :updated_at, :external_key, :data)
        .map { |e| e.to_hash.with_indifferent_access }
    end

    def to_hash
      {
        external_system_id: external_system_id,
        external_identifier: external_system.identifier,
        created_at: created_at,
        updated_at: updated_at,
        external_key: external_key
      }
    end
  end
end
