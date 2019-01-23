# frozen_string_literal: true

module DataCycleCore
  module Translations
    # Module loading ActiveRecord-specific classes for Translations models.
    module ActiveRecord
      def self.included(model_class)
        model_class.class_eval do
          unless const_defined?(:UniquenessValidator)
            const_set(:UniquenessValidator,
                      Class.new(DataCycleCore::Translations::ActiveRecord::UniquenessValidator))
          end
          delegate :translated_attribute_names, to: :class
        end
      end
    end
  end
end
