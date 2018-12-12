# frozen_string_literal: true

module DataCycleCore
  class ExternalSystem < ApplicationRecord
    has_many :thing_external_systems, dependent: :destroy
    has_many :things, through: :thing_external_systems

    def push_config
      config&.dig('push_config')&.symbolize_keys
    end

    def refresh_config
      config&.dig('refresh_config')&.symbolize_keys
    end

    def refresh(options = {})
      raise "Missing refresh_strategy for #{name}, options given: #{options}" if refresh_config.dig(:strategy).blank?
      utility_object = DataCycleCore::Export::RefreshObject.new(external_system: self)
      refresh_config.dig(:strategy).constantize.process(utility_object: utility_object)
    end
  end
end
