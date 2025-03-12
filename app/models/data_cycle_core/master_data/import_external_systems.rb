# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSystems
      PROPERTIES_WITH_MODULE_PATHS = [
        'endpoint',
        'download_strategy',
        'import_strategy'
      ].freeze

      DEFAULTS = {
        'name' => nil,
        'identifier' => nil,
        'credentials' => nil,
        'config' => nil,
        'default_options' => nil,
        'deactivated' => false,
        'module_base' => nil
      }.freeze

      DEFAULT_MODULE_BASE = 'DataCycleCore::Generic::Common'

      STRATEGIES_WITH_TRANSFORMATIONS = [
        'DataCycleCore::Generic::Common::ImportContents'
      ].freeze

      def self.import_all(paths: nil, validation: true)
        # remove credentials for safety, when running imported live database
        DataCycleCore::ExternalSystem.update_all(credentials: nil)

        load_all(validation:, paths:) do |data|
          external_system = DataCycleCore::ExternalSystem.find_by(identifier: data['identifier']) || DataCycleCore::ExternalSystem.find_or_initialize_by(name: data['name'])
          external_system.attributes = data
          external_system.save
        end
      end

      def self.validate_all(paths: nil)
        load_all(paths:, validation: true)
      end

      def self.load_all(paths: nil, validation: true)
        errors = []
        paths = paths.present? ? Array.wrap(paths) : [DataCycleCore.external_sources_path, DataCycleCore.external_systems_path]
        paths = paths&.flatten&.compact
        file_paths = Dir.glob(Array.wrap(paths&.flatten&.map { |p| p.join(Rails.env, '*.yml') }))
        file_paths.concat(Dir.glob(Array.wrap(paths&.map { |p| p.join('*.yml') })))
        file_paths.uniq! { |p| File.basename(p) }

        if file_paths.blank?
          puts AmazingPrint::Colors.yellow('INFO: no external systems found') # rubocop:disable Rails/Output
          return
        end

        file_paths.each do |file_name|
          data = YAML.safe_load(File.open(file_name), permitted_classes: [Symbol], aliases: true)
          transform_data!(data)

          if validation
            error = validate(data.deep_symbolize_keys)
            errors.concat(error)
          end

          yield data if error.blank?
        rescue StandardError => e
          errors.push("#{file_name} => could not access the YML File (#{e.message})")
        end

        errors
      end

      def self.transform_data!(data)
        return if data.blank?

        data['identifier'] ||= data['name']
        module_base = data['module_base']

        add_defaults!(data.dig('config', 'download_config'), module_base)
        add_defaults!(data.dig('config', 'import_config'), module_base)
        add_default_transformations!(data, module_base)

        data.reverse_merge!(DEFAULTS)
        data.slice!(*DEFAULTS.keys)
        data
      end

      def self.add_default_transformations!(data, module_base)
        return if data.blank? || module_base.blank?

        if data.dig('default_options', 'transformations').present?
          data['default_options']['transformations'] = full_module_path(module_base, data['default_options']['transformations'])
        elsif data.dig('config', 'download_config')&.any? { |_, v| v['import_strategy']&.in?(STRATEGIES_WITH_TRANSFORMATIONS) } ||
              data.dig('config', 'import_config')&.any? { |_, v| v['import_strategy']&.in?(STRATEGIES_WITH_TRANSFORMATIONS) }
          data['default_options'] ||= {}
          data['default_options']['transformations'] = full_module_path(module_base, 'Transformations')
        end
      end

      def self.add_defaults!(data, module_base)
        return if data.blank?

        data.each.with_index(1) do |(key, value), index|
          value['sorting'] ||= index

          append_source_type!(value, key)
          append_module_base!(value, module_base)
        end
      end

      def self.append_source_type!(value, key)
        return if value.key?('source_type')

        strategy = (value['import_strategy'] || value['download_strategy'])&.safe_constantize
        value['source_type'] = key unless strategy.try(:source_type?).is_a?(FalseClass)
      end

      def self.append_module_base!(value, module_base)
        return if value.blank? || module_base.blank?

        value.each do |key, v|
          next unless v.is_a?(String) && PROPERTIES_WITH_MODULE_PATHS.include?(key)

          value[key] = full_module_path(module_base, v)
        end
      end

      def self.full_module_path(module_base, module_name, namespace = 'Import')
        return module_name if module_base.blank?
        return module_name if module_name.safe_constantize&.class&.in?([Module, Class])

        module_path = "#{module_base}::#{module_name}"
        return module_path if module_path.safe_constantize&.class&.in?([Module, Class])

        module_path = "#{module_base}::#{namespace}::#{module_name}"
        return module_path if module_path.safe_constantize&.class&.in?([Module, Class])

        module_path = "#{DEFAULT_MODULE_BASE}::#{module_name}"
        return module_path if module_path.safe_constantize&.class&.in?([Module, Class])

        module_name
      end

      def self.validate(data_hash)
        validation_hash = data_hash.deep_symbolize_keys
        validate_header = ExternalSystemHeaderContract.new

        errors = validate_header.call(validation_hash).errors.map do |error|
          "#{data_hash[:name]}.#{error.path.join('.')} => #{error}"
        end

        [:import_config, :download_config].each do |config_key|
          validator = ExternalSystemStepContract.new
          data = validation_hash.dig(:config, config_key) || {}

          if data.is_a?(Hash)
            data.each do |key, value|
              validator.call(value).errors.each do |error|
                error_path = [data_hash[:name], 'config', config_key, key, *error.path].compact_blank.join('.')
                errors.push("#{error_path} => #{error}")
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
          optional(:credentials).maybe { array? | hash? }
          optional(:deactivated) { bool? }
          optional(:module_base).maybe(:ruby_module_or_class?)
          optional(:default_options).maybe(:hash) do
            optional(:locales).each { str? & included_in?(I18n.available_locales.map(&:to_s)) }
            optional(:error_notification).hash do
              optional(:emails).each { str? & format?(Devise.email_regexp) }
              optional(:grace_period) { str? }
            end
            optional(:ai_model) { str? }
            optional(:endpoint).filled(:ruby_class?)
            optional(:transformations).filled(:ruby_module?)
          end
          optional(:config).maybe(:hash) do
            optional(:api_strategy).filled(:ruby_class?)
            optional(:export_config).hash do
              optional(:endpoint).filled(:ruby_class?)
              optional(:filter) { hash? }
              optional(:create).hash do
                required(:strategy).filled(:ruby_module?)
                optional(:filter) { hash? }
              end
              optional(:update).hash do
                required(:strategy).filled(:ruby_module?)
                optional(:filter) { hash? }
              end
              optional(:delete).hash do
                required(:strategy).filled(:ruby_module?)
                optional(:filter) { hash? }
              end
            end
            optional(:refresh_config).maybe(:hash) do
              optional(:endpoint).filled(:ruby_class?)
              required(:strategy).filled(:ruby_module?)
            end
            optional(:download_config).maybe(:hash)
            optional(:import_config).maybe(:hash)
          end
        end

        rule(:credentials).validate(:dc_unique_credentials)
        rule(:credentials).validate(:dc_credential_keys)

        rule('config.export_config.filter').validate(:filter_config)
        rule('config.export_config.create.filter').validate(:filter_config)
        rule('config.export_config.update.filter').validate(:filter_config)
        rule('config.export_config.delete.filter').validate(:filter_config)
      end

      class ExternalSystemStepContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:sorting) { int? & gt?(0) }
          optional(:source_type).filled(:str?)
          optional(:read_type) { str? | (array? & each { str? }) }
          optional(:endpoint).filled(:ruby_class?)
          optional(:import_strategy).filled(:ruby_module?)
          optional(:download_strategy).filled(:ruby_module?)
          optional(:logging_strategy).filled(:str?)
          optional(:tree_label) { str? | (array? & each { str? }) }
          optional(:template_name) { str? | (array? & each { str? }) }
          optional(:linked_template_name) { str? | (array? & each { str? }) }
          optional(:tag_id_path) { str? }
          optional(:tag_name_path) { str? }
          optional(:external_id_prefix).filled(:str?)
          optional(:transformations) { hash? }
          optional(:locales).each { str? & included_in?(I18n.available_locales.map(&:to_s)) }
          optional(:data_id_transformation).filled(:ruby_module_and_method?).hash do
            required(:module) { str? }
            required(:method) { str? }
          end
        end

        rule(:logging_strategy).validate(:dc_logging_strategy)
        rule(:template_name).validate(:dc_template_names)
        rule(:linked_template_name).validate(:dc_template_names)

        rule do
          base.failure(:strategy_required) unless values.key?(:import_strategy) || values.key?(:download_strategy)
        end
      end
    end
  end
end
