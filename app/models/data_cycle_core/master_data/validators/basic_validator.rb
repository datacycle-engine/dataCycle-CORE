module DataCycleCore
  module MasterData
    module Validators
      class BasicValidator

        attr_reader :error

        def initialize(data,template, schema=true)
          @error = { error: [], warning: []}
          @schema = schema
          if schema
            validate(data,template)
          else
            validate_hash(data,template)
          end
        end

        def validate(data,template)
        end

        def merge_errors(error_hash)
          @error.each do |key,items|
            @error[key]+=error_hash[key] if error_hash.has_key?(key)
          end
        end
      end
    end
  end
end
