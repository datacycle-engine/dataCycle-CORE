# frozen_string_literal: true

module DataCycleCore
  class ExternalSystem < ApplicationRecord
    has_many :thing_external_systems, dependent: :destroy
    has_many :things, through: :thing_external_systems

    def push_config
      config&.dig('push_config')&.symbolize_keys
    end
  end
end
