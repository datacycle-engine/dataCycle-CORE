module DataCycleCore
  module MasterData
    class ValidateData
      attr_reader :error

      def initialize
        @error = { error: {}, warning: {} }
      end

      # keys of the data-hash defined as keys in the template
      def validate(data, validation_hash, strict = false, verbose = false)
        if data.blank?
          (@error[:error][validation_hash['name']&.parameterize(separator: '_')] ||= []) << I18n.t(:no_data, scope: [:validation, :errors], locale: DataCycleCore.ui_language)
          return @error
        end
        if validation_hash.blank?
          (@error[:error][validation_hash['name']&.parameterize(separator: '_')] ||= []) << I18n.t(:no_validation, scope: [:validation, :errors], locale: DataCycleCore.ui_language)
          return @error
        end

        ap data if verbose
        ap validation_hash if verbose

        validation_object = Validators::Object.new(data, validation_hash['properties'])
        @error = validation_object.error
      end

      # keys of the data-hash defined as keys in the template
      def valid?(data, validation_hash, strict = false, verbose = false)
        validate(data, validation_hash, strict, verbose)
        if strict
          return (@error[:error].length + @error[:warning].length).zero?
        else
          return @error[:error].empty?
        end
      end
    end
  end
end
