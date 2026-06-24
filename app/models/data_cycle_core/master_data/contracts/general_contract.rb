# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class GeneralContract < Dry::Validation::Contract
        config.messages.default_locale = :en
        config.messages.backend = :i18n

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

        register_macro(:dc_unique_credentials) do
          if value.is_a?(Array)
            md5_hashes = value.map { |v| Digest::MD5.hexdigest(v.except(:credential_key).to_s) }
            key.failure('all credentials must be unique') if md5_hashes.uniq.size != md5_hashes.size
          end
        end

        register_macro(:dc_logging_strategy) do
          temp = begin
            Class.new.instance_eval(value)
          rescue StandardError
            false
          end

          key.failure('the string given does not specify a valid logging class.') if temp == false && key?
        end

        register_macro(:dc_template_names) do
          # remove Rails.env.development?, when database is available in gitlab for validations
          key.failure('the specified template_names do not exist in this project') if key? && Rails.env.development? && !DataCycleCore::ThingTemplate.exists?(template_name: value)
        end

        register_macro(:ruby_module_and_method) do |macro:|
          next unless key? && value.is_a?(Hash) && value.key?(:module) && value.key?(:method)

          params = [
            "Module: #{value[:module]}",
            "Method: #{value[:method]}"
          ]
          params.unshift("Namespace: #{macro.args.first}") if macro.args.first.present?
          message = "module and method combination not found (#{params.join(', ')})."
          key.failure(message) unless DataCycleCore::ModuleService.load_module(value[:module], macro.args.first).respond_to?(value[:method])
        rescue NameError
          key.failure(message)
        end

        register_macro(:duplicate_candidate_module) do
          next unless key? && (value.is_a?(String) || value.is_a?(Array))

          Array.wrap(value).each do |v|
            context = "Class: #{v}, Namespace: #{Feature::DuplicateCandidate::MODULE_BASE_PATH}"
            dc_module = DataCycleCore::ModuleService.load_module(v, Feature::DuplicateCandidate::MODULE_BASE_PATH)
            key.failure("Class not found (#{context}).") unless dc_module

            key.failure("Class found, but missing required class method 'duplicates' (#{context}).") unless dc_module.respond_to?(:duplicates)
            key.failure("Class found, but missing required class method 'parameters' (#{context}).") unless dc_module.respond_to?(:parameters)
          rescue NameError
            key.failure("Class not found (#{context}).")
          end
        end

        register_macro(:dc_property_validations) do
          next unless key? && value.is_a?(Hash)

          missing = []

          value.each_key do |k|
            validator = DataCycleCore::MasterData::Validators::Object::BASIC_TYPES[values['type']]

            next missing << k unless validator&.private_method_defined?(k)
          end

          key.failure("The following Validations do not exist: #{missing.join(', ')}") if missing.present?
        end

        register_macro(:touch_step_required) do
          next unless key? && value.demodulize.in?(['DownloadBulkMarkDeleted', 'DownloadMarkDeleted'])

          source_type = values[:source_type]

          next unless steps&.values&.any? { |v| v[:source_type] == source_type && v[:download_strategy]&.include?('DownloadDataFromData') }

          next if steps&.values&.any? { |v| v[:source_type] == source_type && v[:download_strategy]&.include?('DownloadBulkTouchFromData') }

          key.failure('DownloadBulkTouchFromData step should be added to prevent deleting all items')
        end

        # At download time the endpoint instance is invoked as
        # `endpoint.send(endpoint_method || source_type)` (see
        # DataCycleCore::Generic::Common::DownloadFunctions). A step whose derived
        # method name does not exist on the endpoint class fails at runtime with a
        # NoMethodError, so reject such mismatches up front.
        #
        # Skipped in the test environment: the gem's fixtures intentionally pair the
        # generic Csv endpoint with placeholder source_types that are never actually
        # downloaded (analogous to the :dc_template_names guard).
        register_macro(:endpoint_method_exists) do
          next if Rails.env.test?
          next unless key? && value.is_a?(String)

          endpoint_class = value.safe_constantize
          next if endpoint_class.nil? # an unloadable endpoint class is already reported by the :ruby_class? predicate

          endpoint_method = (values[:endpoint_method].presence || values[:source_type].presence)&.to_s
          next if endpoint_method.blank?
          next if endpoint_class.method_defined?(endpoint_method) || endpoint_class.private_method_defined?(endpoint_method)

          derived_from = values[:endpoint_method].present? ? 'endpoint_method' : 'source_type'
          key.failure("endpoint '#{value}' does not define method '#{endpoint_method}' (derived from #{derived_from})")
        end
      end
    end
  end
end
