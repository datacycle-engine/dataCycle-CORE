module DataCycleCore
  module StringExtension
    def attribute_name_from_key
      split(/[\[\]]+/).last.underscore
    end
  end
end

String.include DataCycleCore::StringExtension
