# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSystems
      def self.import_all(validation: true, paths: nil)
        # remove credentials for safety, when running imported live database
        DataCycleCore::ExternalSystem.update_all(credentials: nil) # rubocop:disable Rails/SkipsModelValidations

        errors = {}
        paths ||= [DataCycleCore.external_sources_path, DataCycleCore.external_systems_path].compact
        file_paths = Dir.glob(Array.wrap(paths&.map { |p| p + Rails.env + '*.yml' })).concat(Dir.glob(Array.wrap(paths&.map { |p| p + '*.yml' }))).uniq { |p| File.basename(p) }

        if file_paths.blank?
          puts 'INFO: no external systems found'
          return
        end

        file_paths.each do |file_name|
          data = YAML.safe_load(File.open(file_name), [Symbol])
          error = validation ? validate(data.deep_symbolize_keys) : nil
          if error.blank?
            external_system = DataCycleCore::ExternalSystem.find_or_initialize_by(name: data['name'])
            data['identifier'] ||= data['name']
            external_system.attributes = data.slice('name', 'identifier', 'credentials', 'config', 'default_options')
            external_system.save
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
        errors = validate_header.call(data_hash.deep_symbolize_keys).errors || {}
        errors[:import_config] = {}
        errors[:download_config] = {}

        import_config = data_hash.dig(:config, :import_config) || {}
        import_config.each do |key, value|
          error = validate_import_item.call(value.deep_symbolize_keys).errors
          errors[:import_config][key] = error if error.present?
        end

        download_config = data_hash.dig(:config, :download_config) || {}
        download_config.each do |key, value|
          error = validate_download_item.call(value.deep_symbolize_keys).errors
          errors[:download_config][key] = error if error.present?
        end

        errors.reject { |_, v| v.blank? }
      end

      def self.validate_header
        Dry::Validation.Schema do
          configure do
            def class?(value)
              if value.safe_constantize.nil?
                false
              else
                value.safe_constantize.class == Class
              end
            end

            def array_or_hash?(value)
              value.is_a?(Array) || value.is_a?(Hash)
            end

            def module?(value)
              if value.safe_constantize.nil?
                false
              else
                value.safe_constantize.class == Module
              end
            end

            def self.messages
              super.merge(
                en: {
                  errors: {
                    class?: 'the string given does not specify a valid ruby class.',
                    module?: 'the string given does not specify a valid ruby module.',
                    array_or_hash?: 'must be either an Array or Hash.'
                  }
                }
              )
            end
          end

          required(:name) { str? }
          optional(:identifier) { str? }
          required(:credentials) { array_or_hash? }
          optional(:api_strategy) { str? & class? }
          optional(:default_options).schema do
            optional(:locales).each { str? }
          end
          optional(:config).schema do
            optional(:download_config) { hash? }
            optional(:import_config) { hash? }
            optional(:export_config).schema do
              optional(:endpoint) { class? }
              optional(:create).schema do
                required(:strategy) { module? }
              end
              optional(:update).schema do
                required(:strategy) { module? }
              end
              optional(:delete).schema do
                required(:strategy) { module? }
              end
            end
            optional(:refresh_config).schema do
              optional(:endpoint) { class? }
              required(:strategy) { module? }
            end

            rule(has_one_config: [:download_config, :import_config, :export_config]) do |download_config, import_config, export_config|
              (download_config.filled? & import_config.filled?) | export_config.filled?
            end
          end
        end
      end

      def self.validate_download_item
        Dry::Validation.Schema do
          configure do
            def module?(value)
              value.safe_constantize.nil? ? false : value.safe_constantize.class == Module
            end

            def class?(value)
              value.safe_constantize.nil? ? false : value.safe_constantize.class == Class
            end

            def logger?(value)
              temp = begin
                       Class.new.instance_eval(value)
                     rescue StandardError
                       false
                     end
              temp == false ? temp : true
            end

            def self.messages
              super.merge(
                en: {
                  errors: {
                    module?: 'the string given does not specify a valid ruby module.',
                    class?: 'the string given does not specify a valid ruby class.',
                    logger?: 'the string given can not be evaluated.'
                  }
                }
              )
            end
          end

          optional(:sorting) { int? & gt?(0) }
          required(:source_type) { str? }
          required(:endpoint) { str? & class? }
          required(:download_strategy) { str? & module? }
          optional(:logging_strategy) { str? & logger? }
        end
      end

      def self.validate_import_item
        Dry::Validation.Schema do
          configure do
            def module?(value)
              value.safe_constantize.nil? ? false : value.safe_constantize.class == Module
            end

            def class?(value)
              value.safe_constantize.nil? ? false : value.safe_constantize.class == Class
            end

            def logger?(value)
              temp = begin
                       Class.new.instance_eval(value)
                     rescue StandardError
                       false
                     end
              temp == false ? temp : true
            end

            def self.messages
              super.merge(
                en: {
                  errors: {
                    module?: 'the string given does not specify a valid ruby module.',
                    class?: 'the string given does not specify a valid ruby class.',
                    logger?: 'the string given can not be evaluated.'
                  }
                }
              )
            end
          end

          optional(:sorting) { int? & gt?(0) }
          required(:source_type) { str? }
          optional(:read_type) { str? }
          required(:import_strategy) { str? & module? }
          optional(:tree_label) { str? }
          optional(:tag_id_path) { str? }
          optional(:tag_name_path) { str? }
          optional(:external_id_prefix) { str? }
          optional(:logging_strategy) { str? & logger? }
          optional(:transformations) { hash? }
        end
      end
    end
  end
end
