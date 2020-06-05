# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class GeneralContract < Dry::Validation::Contract
        config.messages.default_locale = :en
        config.messages.backend = :i18n

        register_macro(:dc_class) do
          key.failure('the string given does not specify a valid ruby class.') if value&.safe_constantize&.class != Class && key?
        end

        register_macro(:dc_array_or_hash) do
          key.failure('the value must be of type Array or Hash') if !value&.is_a?(Hash) && !value&.is_a?(Array) && key?
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
