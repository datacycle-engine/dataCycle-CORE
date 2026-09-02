# frozen_string_literal: true

module DataCycleCore
  class ExternalSystemSync < ApplicationRecord
    include ExternalSystemExtensions::UrlTemplate

    SYNC_TYPES = {
      export: 'export',
      duplicate: 'duplicate',
      import: 'import'
    }.freeze
    FAILURE_STATUSES = ['error', 'failure'].freeze

    belongs_to :syncable, polymorphic: true
    belongs_to :external_system
    belongs_to :thing, -> { where(external_system_syncs: { syncable_type: 'DataCycleCore::Thing' }) }, class_name: 'DataCycleCore::Thing', foreign_key: 'syncable_id', optional: true, inverse_of: :external_system_syncs

    validates :external_system_id, presence: true # rubocop:disable Rails/RedundantPresenceValidationOnBelongsTo

    scope :export, -> { where(sync_type: SYNC_TYPES[:export]) }
    scope :import, -> { where(sync_type: SYNC_TYPES[:import]) }
    # DataCycleCore::WebhookJob writes the row before it sends the request, so its existence alone
    # says nothing about the receiver. Excluded is only what demonstrably never arrived: never
    # reported a success and ended in a failure state. A row that succeeded once and failed later is
    # at the receiver in its older form and still has to be deleted there.
    scope :delivered, -> { where("external_system_syncs.last_successful_sync_at IS NOT NULL OR COALESCE(external_system_syncs.status, '') NOT IN (?)", FAILURE_STATUSES) }
    # What a receiver holds, for the per-record question in DataCycleCore::Export::Generic::Filter and
    # for the relation DataCycleCore::Thing.delivered_to builds on
    scope :delivered_to, ->(external_system) { export.delivered.where(external_system_id: external_system.id) }
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
        format_url_template(external_system.default_options(:export)['external_url'], locale: I18n.locale, type:, external_key:)
      end
    end

    def append_external_key
      external_system.default_options(:export)['external_url'] + external_key
    end

    # read for this row's own sync_type, not for :export - a system may configure the template
    # for imports only (e.g. outdooractive on moselland), and an import sync then has to resolve
    # it too. Types without their own section (duplicate, ...) fall back to the root config.
    def external_detail_url
      return data['external_detail_url'] if data&.dig('external_detail_url').present?
      return if !syncable.is_a?(DataCycleCore::Thing) || external_key.blank?

      template = external_system&.default_options(sync_type)&.dig('external_detail_url')
      return if template.blank?

      format_url_template(template, locale: I18n.locale, type:, external_key:)
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

    # normalizes any connector's failure payload into the same (string-keyed) shape as
    # WebhookJob#exception_data. returns nil when a hash carries no recognizable error
    # text, so it can be applied to a full sync data hash without dumping unrelated keys.
    def self.exception_data_from(data)
      return if data.blank?

      text = if data.is_a?(Hash)
               data.with_indifferent_access.values_at('errors', 'error', 'job_message', 'message').find(&:present?)
             else
               data
             end
      return if text.blank?

      { 'timestamp' => Time.zone.now, 'text' => text.to_s }
    end

    # the error to show in the UI: the stored exception_data for failures recorded since it
    # was populated, otherwise derived from the raw sync data (covers pre-existing failures
    # without a backfill migration). only failed syncs surface an error.
    def display_exception_data
      exception_data.presence ||
        (status.in?(FAILURE_STATUSES) ? self.class.exception_data_from(data) : nil)
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
