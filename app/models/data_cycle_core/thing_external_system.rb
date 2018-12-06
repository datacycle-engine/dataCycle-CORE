# frozen_string_literal: true

module DataCycleCore
  class ThingExternalSystem < ApplicationRecord
    belongs_to :thing
    belongs_to :external_system

    def self.with_external_system(external_system_id)
      find_by(external_system_id: external_system_id)
    end
  end
end
