module DataCycleCore
  module MasterData
    module Validators
      class BasicValidator
        attr_reader :error

        def initialize(data, template)
          @error = { error: [], warning: [] }
          validate(data, template)
        end

        def validate(data, template)
        end

        def merge_errors(error_hash)
          @error.each_key do |key|
            @error[key] += error_hash[key] if error_hash.key?(key)
          end
        end
      end
    end
  end
end
