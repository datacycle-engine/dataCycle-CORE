# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSystems
      def self.import_all(validation: true, paths: nil)
        # remove credentials for safety, when running imported live database
        DataCycleCore::ExternalSystem.update_all(credentials: nil)

        errors = []
        paths ||= [DataCycleCore.external_sources_path, DataCycleCore.external_systems_path]
        paths = paths&.flatten&.compact
        file_paths = Dir.glob(Array.wrap(paths&.flatten&.map { |p| p.join(Rails.env, '*.yml') })).concat(Dir.glob(Array.wrap(paths&.map { |p| p.join('*.yml') }))).uniq { |p| File.basename(p) }

        if file_paths.blank?
          puts AmazingPrint::Colors.yellow('INFO: no external systems found')
          return
        end

        file_paths.each do |file_name|
          data = YAML.safe_load(File.open(file_name), permitted_classes: [Symbol], aliases: true)
          error = validation ? validate(data.deep_symbolize_keys) : nil
          if error.blank?
            external_system = DataCycleCore::ExternalSystem.find_by(identifier: data['identifier']) || DataCycleCore::ExternalSystem.find_or_initialize_by(name: data['name'])
            data['identifier'] ||= data['name']

            add_sorting!(data.dig('config', 'download_config'))
            add_sorting!(data.dig('config', 'import_config'))

            external_system.attributes = data.slice('name', 'identifier', 'credentials', 'config', 'default_options', 'deactivated').reverse_merge!({ 'name' => nil, 'identifier' => nil, 'credentials' => nil, 'config' => nil, 'default_options' => nil, 'deactivated' => false })
            external_system.save
          else
            errors.concat(error)
          end
        rescue StandardError => e
          puts AmazingPrint::Colors.red("🔥 could not access the YML File #{file_name}")
          puts e.message
          puts e.backtrace
        end

        errors
      end

      def self.add_sorting!(data)
        return if data.blank?

        data.each_value.with_index(1) do |value, index|
          value['sorting'] ||= index
        end
      end

      def self.validate_all
        errors = []
        paths = [DataCycleCore.external_sources_path, DataCycleCore.external_systems_path]
        paths = paths&.flatten&.compact
        file_paths = Dir.glob(Array.wrap(paths&.flatten&.map { |p| p.join(Rails.env, '*.yml') })).concat(Dir.glob(Array.wrap(paths&.map { |p| p.join('*.yml') }))).uniq { |p| File.basename(p) }

        if file_paths.blank?
          puts AmazingPrint::Colors.yellow('INFO: no external systems found')
          return
        end

        file_paths.each do |file_name|
          data = YAML.safe_load(File.open(file_name), permitted_classes: [Symbol], aliases: true)
          errors.concat(validate(data.deep_symbolize_keys))
        rescue StandardError => e
          puts AmazingPrint::Colors.red("🔥 could not access the YML File #{file_name}")
          puts e.message
          puts e.backtrace
        end

        errors
      end

      def self.validate(data_hash)
        validation_hash = data_hash.deep_symbolize_keys
        validate_header = ExternalSystemHeaderContract.new

        errors = validate_header.call(validation_hash).errors.map do |error|
          "#{data_hash[:name]}.#{error.path.join('.')} => #{error.text}"
        end

        [:import_config, :download_config].each do |config_key|
          validator = ExternalSystemStepContract.new
          data = validation_hash.dig(:config, config_key) || {}

          if data.is_a?(Hash)
            data.each do |key, value|
              validator.call(value).errors.each do |error|
                error_path = [data_hash[:name], 'config', config_key, key, *error.path].compact_blank.join('.')
                errors.push("#{error_path} => #{error.text}")
              end
            end
          else
            errors.push("#{data_hash[:name]}.config.#{config_key} => Import config must be a Hash")
          end
        end

        errors
      end

      class ExternalSystemHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        register_macro(:filter_config) do
          key.failure('incompatible filter config for webhooks, endpoints cannot be used in combination with specific filters') if value&.key?(:endpoints) && value&.keys&.except(:endpoints).present?
        end

        # Regex for matching if a string can be interpreted as a valid ActiveSupport::Duration
        # Should match things like 1.day, 2.hours, 3.months, 5.year, ...
        schema do
          required(:name) { str? }
          optional(:identifier) { str? }
          optional(:credentials)
          optional(:default_options).hash do
            optional(:locales).each { str? & included_in?(I18n.available_locales.map(&:to_s)) }
            optional(:error_notification).hash do
              optional(:emails).each { str? & format?(Devise.email_regexp) }
              optional(:grace_period) { str? }
            end
            optional(:ai_model) { str? }
            optional(:endpoint) { str? }
            optional(:transformations) { str? }
          end
          optional(:config).hash do
            optional(:api_strategy) { str? }
            optional(:export_config).hash do
              optional(:endpoint) { str? }
              optional(:filter) { hash? }
              optional(:create).hash do
                required(:strategy) { str? }
                optional(:filter) { hash? }
              end
              optional(:update).hash do
                required(:strategy) { str? }
                optional(:filter) { hash? }
              end
              optional(:delete).hash do
                required(:strategy) { str? }
                optional(:filter) { hash? }
              end
            end
            optional(:refresh_config).hash do
              optional(:endpoint) { str? }
              required(:strategy) { str? }
            end
            optional(:download_config) { hash? }
            optional(:import_config) { hash? }
          end
        end

        rule(:credentials).validate(:dc_array_or_hash)

        rule(:credentials).validate(:dc_unique_credentials)
        rule(:credentials).validate(:dc_credential_keys)

        rule(config: :api_strategy).validate(:dc_class)

        rule('config.export_config.endpoint').validate(:dc_class)
        rule('config.refresh_config.endpoint').validate(:dc_class)
        rule('default_options.endpoint').validate(:dc_class)

        rule('default_options.transformations').validate(:dc_module)

        rule('config.export_config.create.strategy').validate(:dc_module)
        rule('config.export_config.update.strategy').validate(:dc_module)
        rule('config.export_config.delete.strategy').validate(:dc_module)

        rule('config.refresh_config.strategy').validate(:dc_module)

        rule('config.export_config.filter').validate(:filter_config)
        rule('config.export_config.create.filter').validate(:filter_config)
        rule('config.export_config.update.filter').validate(:filter_config)
        rule('config.export_config.delete.filter').validate(:filter_config)
      end

      class ExternalSystemStepContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          optional(:read_type) { str? | (array? & each { str? }) }
          optional(:sorting) { int? & gt?(0) }
          optional(:source_type) { str? }
          optional(:endpoint) { str? }
          optional(:import_strategy) { str? }
          optional(:download_strategy) { str? }
          optional(:logging_strategy) { str? }
          optional(:tree_label) { str? | (array? & each { str? }) }
          optional(:tag_id_path) { str? }
          optional(:tag_name_path) { str? }
          optional(:external_id_prefix) { str? }
          optional(:logging_strategy) { str? }
          optional(:transformations) { hash? }
          optional(:locales).each { str? & included_in?(I18n.available_locales.map(&:to_s)) }
          optional(:data_id_transformation).hash do
            required(:module) { str? }
            required(:method) { str? }
          end
        end

        rule(:endpoint).validate(:dc_class)
        rule(:download_strategy).validate(:dc_module)
        rule(:import_strategy).validate(:dc_module)
        rule(:logging_strategy).validate(:dc_logging_strategy)
        rule(:data_id_transformation).validate(:dc_module_method)

        rule do
          base.failure(:strategy_required) unless values.key?(:import_strategy) || values.key?(:download_strategy)
        end

        rule(:source_type).validate(:source_type_required)
      end
    end
  end
end
