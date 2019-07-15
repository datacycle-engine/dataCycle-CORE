# frozen_string_literal: true

module DataCycleCore
  class ExternalSystem < ApplicationRecord
    has_many :external_system_syncs, dependent: :destroy
    has_many :things, through: :external_system_syncs, source: :syncable, source_type: 'DataCycleCore::Thing'
    has_many :users, through: :external_system_syncs, source: :syncable, source_type: 'DataCycleCore::User'

    def push_config
      config&.dig('push_config')&.symbolize_keys
    end

    def refresh_config
      config&.dig('refresh_config')&.symbolize_keys
    end

    def refresh(options = {})
      raise "Missing refresh_strategy for #{name}, options given: #{options}" if refresh_config.dig(:strategy).blank?
      utility_object = DataCycleCore::Export::RefreshObject.new(external_system: self)
      refresh_config.dig(:strategy).constantize.process(utility_object: utility_object, options: options)
    end
  end
end
