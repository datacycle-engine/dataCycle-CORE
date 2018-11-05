# frozen_string_literal: true

module DataCycleCore
  module Common
    extend ActiveSupport::Concern

    def data_cycle_object(object_string)
      object_type = DataCycleCore.content_tables.find { |object| object == object_string }
      return unless object_type

      ('DataCycleCore::' + object_type.singularize.classify).constantize
    end
  end
end
