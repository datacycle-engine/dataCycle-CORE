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
        file_paths = Dir.glob(Array.wrap(paths&.flatten&.map { |p| p + Rails.env + '*.yml' })).concat(Dir.glob(Array.wrap(paths&.map { |p| p + '*.yml' }))).uniq { |p| File.basename(p) }

        if file_paths.blank?
          puts 'INFO: no external systems found'
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
          puts "could not access the YML File #{file_name}"
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
        file_paths = Dir.glob(Array.wrap(paths&.flatten&.map { |p| p + Rails.env + '*.yml' })).concat(Dir.glob(Array.wrap(paths&.map { |p| p + '*.yml' }))).uniq { |p| File.basename(p) }

        if file_paths.blank?
          puts 'INFO: no external systems found'
          return
        end

        file_paths.each do |file_name|
          data = YAML.safe_load(File.open(file_name), permitted_classes: [Symbol], aliases: true)
          errors.concat(validate(data.deep_symbolize_keys))
        rescue StandardError => e
          puts "could not access the YML File #{file_name}"
          puts e.message
          puts e.backtrace
        end

        errors
      end

      def self.validate(data_hash)
        validation_hash = data_hash.deep_symbolize_keys
        validate_header = ExternalSystemHeaderContract.new

        errors = []

        validate_header.call(validation_hash).errors.each do |error|
          errors.push("#{data_hash[:name]}.#{error.path.join('.')} => #{error.text}")
        end

        validate_import = ExternalSystemImportContract.new
        import_config = validation_hash.dig(:config, :import_config) || {}
        if import_config.is_a?(Hash)
          import_config.each do |key, value|
            validate_import.call(value).errors.each do |error|
              errors.push("#{data_hash[:name]}.config.import_config.#{key}.#{error.path.join('.')} => #{error.text}")
            end
          end
        else
          errors.push("#{data_hash[:name]}.config.import_config.general => Import config must be a Hash")
        end

        validate_download = ExternalSystemDownloadContract.new
        download_config = validation_hash.dig(:config, :download_config) || {}
        if download_config.is_a?(Hash)
          download_config.each do |key, value|
            validate_download.call(value).errors.each do |error|
              errors.push("#{data_hash[:name]}.config.download_config.#{key}.#{error.path.join('.')} => #{error.text}")
            end
          end
        else
          errors.push("#{data_hash[:name]}.config.download_config.general => Download config must be a Hash")
        end

        errors
      end

      class ExternalSystemHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        register_macro(:filter_config) do
          key.failure('incompatible filter config for webhooks, endpoints cannot be used in combination with specific filters') if value&.key?(:endpoints) && value&.keys&.except(:endpoints).present?
        end

        schema do
          required(:name) { str? }
          optional(:identifier) { str? }
          optional(:credentials)
          optional(:default_options).hash do
            optional(:locales).each { str? & included_in?(I18n.available_locales.map(&:to_s)) }
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
        rule(config: :api_strategy).validate(:dc_class)

        rule('config.export_config.endpoint').validate(:dc_class)
        rule('config.refresh_config.endpoint').validate(:dc_class)

        rule('config.export_config.create.strategy').validate(:dc_module)
        rule('config.export_config.update.strategy').validate(:dc_module)
        rule('config.export_config.delete.strategy').validate(:dc_module)

        rule('config.refresh_config.strategy').validate(:dc_module)

        rule('config.export_config.filter').validate(:filter_config)
        rule('config.export_config.create.filter').validate(:filter_config)
        rule('config.export_config.update.filter').validate(:filter_config)
        rule('config.export_config.delete.filter').validate(:filter_config)
      end

      class ExternalSystemDownloadContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          optional(:sorting) { int? & gt?(0) }
          required(:source_type) { str? }
          optional(:endpoint) { str? }
          required(:download_strategy) { str? }
          optional(:logging_strategy) { str? }
          optional(:locales).each { str? & included_in?(I18n.available_locales.map(&:to_s)) }
        end

        rule(:endpoint).validate(:dc_class)
        rule(:download_strategy).validate(:dc_module)
        rule(:logging_strategy).validate(:dc_logging_strategy)
      end

      class ExternalSystemImportContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          optional(:sorting) { int? & gt?(0) }
          required(:source_type) { str? }
          optional(:read_type) { str? }
          required(:import_strategy) { str? }
          optional(:tree_label) { str? }
          optional(:tag_id_path) { str? }
          optional(:tag_name_path) { str? }
          optional(:external_id_prefix) { str? }
          optional(:logging_strategy) { str? }
          optional(:transformations) { hash? }
          optional(:locales).each { str? & included_in?(I18n.available_locales.map(&:to_s)) }
        end

        rule(:import_strategy).validate(:dc_module)
        rule(:logging_strategy).validate(:dc_logging_strategy)
      end
    end
  end
end
