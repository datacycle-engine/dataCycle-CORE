# frozen_string_literal: true

require 'translations/arel'

module Translations
  # Module loading ActiveRecord-specific classes for Translations models.
  module ActiveRecord
    require 'translations/active_record/uniqueness_validator'

    def self.included(model_class)
      model_class.class_eval do
        unless const_defined?(:UniquenessValidator)
          const_set(:UniquenessValidator,
                    Class.new(::Translations::ActiveRecord::UniquenessValidator))
        end
        delegate :translated_attribute_names, to: :class
      end
    end
  end
end
