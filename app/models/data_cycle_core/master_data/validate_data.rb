# frozen_string_literal: true

module DataCycleCore
  module MasterData
    class ValidateData
      attr_reader :error

      def initialize(content = nil)
        @content = content
        @error = { error: {}, warning: {} }
      end

      # keys of the data-hash defined as keys in the template
      def validate(data, validation_hash, strict = false, verbose = false)
        if data.blank?
          (@error[:error][validation_hash['name']&.parameterize(separator: '_')] ||= []) << { path: 'validation.errors.no_data' }
          return @error
        end
        if validation_hash.blank?
          (@error[:error][validation_hash['name']&.parameterize(separator: '_')] ||= []) << { path: 'validation.errors.no_validation' }
          return @error
        end

        ap data if verbose
        ap validation_hash if verbose

        validation_object = Validators::Object.new(data, validation_hash['properties'], '', strict, @content)
        @error = validation_object.error
      end

      # keys of the data-hash defined as keys in the template
      def valid?(data, validation_hash, strict = false, verbose = false)
        validate(data, validation_hash, strict, verbose)
        return (@error[:error].length + @error[:warning].length).zero? if strict
        @error[:error].empty?
      end
    end
  end
end
