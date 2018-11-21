# frozen_string_literal: true

module DataCycleCore
  module Common
    extend ActiveSupport::Concern

    def data_cycle_object(object_string)
      return unless object_string == 'things'

      DataCycleCore::Thing
    end
  end
end
