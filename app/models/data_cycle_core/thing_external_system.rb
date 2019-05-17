# frozen_string_literal: true

module DataCycleCore
  class ThingExternalSystem < ApplicationRecord
    belongs_to :thing
    belongs_to :external_system

    def external_url
      return if external_system&.default_options&.dig('external_url').blank? || external_key.blank?

      format(external_system.default_options.dig('external_url'), locale: I18n.locale, type: type, external_key: external_key)
    end

    def type
      external_system&.default_options&.dig('type_mapping', thing.template_name) || thing.template_name.underscore_blanks
    end

    def external_key
      data&.dig(external_system&.default_options&.dig('external_key_param') || 'external_key')
    end

    def self.with_external_system(external_system_id)
      find_by(external_system_id: external_system_id)
    end
  end
end
