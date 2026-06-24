# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemSync < ApplicationRecord
    SYNC_TYPES = {
      export: 'export',
      duplicate: 'duplicate',
      import: 'import'
    }.freeze

    belongs_to :syncable, polymorphic: true
    belongs_to :external_system
    belongs_to :thing, -> { where(external_system_syncs: { syncable_type: 'DataCycleCore::Thing' }) }, class_name: 'DataCycleCore::Thing', foreign_key: 'syncable_id', optional: true, inverse_of: :external_system_syncs

    validates :external_system_id, presence: true # rubocop:disable Rails/RedundantPresenceValidationOnBelongsTo

    scope :export, -> { where(sync_type: SYNC_TYPES[:export]) }
    scope :import, -> { where(sync_type: SYNC_TYPES[:import]) }
    scope :with_import_config, -> { joins(:external_system).merge(ExternalSystem.with_import_config) }
    scope :with_active_config, -> { joins(:external_system).merge(ExternalSystem.activated) }
    store_accessor :data, :exported_data
    attribute :exported_data, :jsonb

    store_accessor :data, :exception, suffix: true
    attribute :exception_data, :jsonb

    store_accessor :data, :job_id
    attribute :job_id, :string
    store_accessor :data, :job_status
    attribute :job_status, :string
    store_accessor :data, :seen_at
    attribute :seen_at, :datetime

    def external_url
      return data['external_url'] if data&.dig('external_url').present?
      return if !syncable.is_a?(DataCycleCore::Thing) || external_system&.default_options(:export)&.dig('external_url').blank? || external_key.blank?

      if external_system.default_options(:export)['external_url_method'].present?
        send(external_system.default_options(:export)['external_url_method'])
      else
        format(external_system.default_options(:export)['external_url'], locale: I18n.locale, type:, external_key:)
      end
    end

    def append_external_key
      external_system.default_options(:export)['external_url'] + external_key
    end

    def external_detail_url
      return data['external_detail_url'] if data&.dig('external_detail_url').present?
      return if !syncable.is_a?(DataCycleCore::Thing) || external_system&.default_options(:export)&.dig('external_detail_url').blank? || external_key.blank?

      format(external_system.default_options(:export)['external_detail_url'], locale: I18n.locale, type:, external_key:)
    end

    def type
      external_system&.default_options(:export)&.dig('type_mapping', syncable.template_name) || syncable.template_name.underscore_blanks
    end

    def external_key
      super || data&.dig(external_system&.default_options(:export)&.dig('external_key_param') || 'external_key')
    end

    def self.with_external_system(external_system_id)
      find_by(external_system_id:)
    end

    def self.to_external_data_hash
      includes(:external_system)
        .select(:external_system_id, :created_at, :updated_at, :external_key, :data)
        .map { |e| e.to_hash.with_indifferent_access }
    end

    def to_hash
      {
        external_system_id:,
        external_identifier: external_system.identifier,
        created_at:,
        updated_at:,
        external_key:
      }
    end
  end
end
