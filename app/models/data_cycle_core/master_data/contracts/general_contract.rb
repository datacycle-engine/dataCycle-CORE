# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class GeneralContract < Dry::Validation::Contract
        config.messages.default_locale = :en
        config.messages.backend = :i18n

        register_macro(:dc_class) do
          key.failure('the string given does not specify a valid ruby class.') if key? && value&.safe_constantize&.class != Class
        end

        register_macro(:dc_array_or_hash) do
          key.failure('the value must be of type Array or Hash') if key? && !value.is_a?(Hash) && !value.is_a?(Array)
        end

        register_macro(:dc_credential_keys) do
          if value.is_a?(Array)
            credential_keys = value.filter_map { |v| v[:credential_key] }
            if credential_keys.any?
              if credential_keys.size != value.size
                key.failure('if any entry has a credential_key, all entries must have one')
              elsif credential_keys.uniq.size != credential_keys.size
                non_unique_keys = credential_keys.select { |k| credential_keys.count(k) > 1 }.uniq
                key.failure("all credential_keys must be unique. The following keys are not unique: #{non_unique_keys.join(', ')}")
              end
            end
          end
        end

        register_macro(:dc_module) do
          key.failure('the string given does not specify a valid ruby module.') if key? && value&.safe_constantize&.class != Module
        end

        register_macro(:dc_logging_strategy) do
          temp = begin
            Class.new.instance_eval(value)
          rescue StandardError
            false
          end

          key.failure('the string given does not specify a valid logging class.') if temp == false && key?
        end

        register_macro(:source_type_required) do
          strategy = (values[:import_strategy] || values[:download_strategy])&.safe_constantize

          key.failure('is missing') unless key? || strategy.try(:source_type?).is_a?(FalseClass)
        end
      end
    end
  end
end
