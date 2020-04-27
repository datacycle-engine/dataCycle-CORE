# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class GeneralContract < Dry::Validation::Contract
        register_macro(:dc_class) do
          key.failure('the string given does not specify a valid ruby class.') if value&.safe_constantize&.class != Class && key?
        end
        register_macro(:dc_module) do
          key.failure('the string given does not specify a valid ruby module.') if value&.safe_constantize&.class != Module && key?
        end
        register_macro(:dc_logging_strategy) do
          temp = begin
            Class.new.instance_eval(value)
                 rescue StandardError
                   false
          end
          key.failure('the string given does not specify a valid logging class.') if temp == false && key?
        end
      end
    end
  end
end
