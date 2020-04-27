# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSources
      def self.import_all(validation: true, external_source_path: nil)
        errors = {}
        external_source_path ||= DataCycleCore.external_sources_path

        if external_source_path.blank?
          puts '###### external sources not found'
          return
        end

        default_file_names = Dir[external_source_path + '*.yml']&.index_by { |f| File.basename(f) } || {}
        specific_file_names = Dir[external_source_path + Rails.env + '*.yml']&.index_by { |f| File.basename(f) } || {}

        file_names = default_file_names.merge(specific_file_names).values
        file_names.each do |file_name|
          data = YAML.safe_load(File.open(file_name), [Symbol])

          error = validation ? validate(data.deep_symbolize_keys) : nil
          if error.blank?
            external_source = DataCycleCore::ExternalSource.find_or_initialize_by(name: data['name'])
            external_source.identifier = data['identifier'] || data['name']
            external_source.credentials = data['credentials']
            external_source.config = data['config']
            external_source.default_options = data['default_options']
            external_source.save
          else
            errors[data['name']] = error
          end
        rescue StandardError => e
          puts "could not access the YML File #{file_name}"
          puts e.message
          puts e.backtrace
        end
        errors
      end

      def self.validate(data_hash)
        validation_hash = data_hash.deep_symbolize_keys
        validate_header = ExternalSourceHeaderContract.new
        errors = validate_header.call(validation_hash).errors.to_h || {}
        errors[:import_config] = {}
        errors[:download_config] = {}

        validate_import = ExternalSourceImportContract.new
        import_config = validation_hash.dig(:config, :import_config) || {}
        import_config.each do |key, value|
          error = validate_import.call(value).errors.to_h
          errors[:import_config][key] = error if error.present?
        end

        validate_download = ExternalSourceDownloadContract.new
        download_config = validation_hash.dig(:config, :download_config) || {}
        download_config.each do |key, value|
          error = validate_download.call(value).errors.to_h
          errors[:download_config][key] = error if error.present?
        end

        errors.reject { |_, v| v.blank? }
      end

      class ExternalSourceHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:name) { str? }
          optional(:identifier) { str? }
          required(:credentials) { array? | hash? }
          optional(:default_options).hash do
            optional(:locales).each { str? }
          end
          optional(:config).hash do
            required(:download_config) { hash? }
            required(:import_config) { hash? }
            optional(:api_strategy) { str? }
          end
        end

        rule(config: :api_strategy).validate(:dc_class)
      end

      class ExternalSourceDownloadContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          optional(:sorting) { int? & gt?(0) }
          required(:source_type) { str? }
          required(:endpoint) { str? }
          required(:download_strategy) { str? }
          optional(:logging_strategy) { str? }
        end

        rule(:endpoint).validate(:dc_class)
        rule(:download_strategy).validate(:dc_module)
        rule(:logging_strategy).validate(:dc_logging_strategy)
      end

      class ExternalSourceImportContract < DataCycleCore::MasterData::Contracts::GeneralContract
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
        end

        rule(:import_strategy).validate(:dc_module)
        rule(:logging_strategy).validate(:dc_logging_strategy)
      end
    end
  end
end
