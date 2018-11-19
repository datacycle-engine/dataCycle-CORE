# frozen_string_literal: true

module DataCycleCore
  module StringExtension
    def attribute_name_from_key
      split(/[\[\]]+/).last&.underscore
    end

    def underscore_blanks
      underscore.parameterize(separator: '_')
    end
  end
end

String.include DataCycleCore::StringExtension
