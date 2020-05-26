# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSystems
      def self.import_all(validation: true, paths: nil)
        # remove credentials for safety, when running imported live database
        DataCycleCore::ExternalSystem.update_all(credentials: nil) # rubocop:disable Rails/SkipsModelValidations

        errors = {}
        (paths ||= [DataCycleCore.external_sources_path, DataCycleCore.external_systems_path])&.compact!
        file_paths = Dir.glob(Array.wrap(paths&.map { |p| p + Rails.env + '*.yml' })).concat(Dir.glob(Array.wrap(paths&.map { |p| p + '*.yml' }))).uniq { |p| File.basename(p) }

        if file_paths.blank?
          puts 'INFO: no external systems found'
          return
        end

        default_file_names = Dir[external_system_path + '*.yml']&.index_by { |f| File.basename(f) } || {}
        specific_file_names = Dir[external_system_path + Rails.env + '*.yml']&.index_by { |f| File.basename(f) } || {}

        file_names = default_file_names.merge(specific_file_names).values
        file_names.each do |file_name|
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
        validate_header = ExternalSystemHeaderContract.new
        errors = validate_header.call(data_hash.deep_symbolize_keys).errors.to_h || {}
        errors.reject { |_, v| v.blank? }
      end

      class ExternalSystemHeaderContract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:name) { str? }
          optional(:identifier) { str? }
          required(:credentials) { array? | hash? }
          optional(:default_options).hash do
            optional(:locales).each { str? }
          end
          required(:config).hash do
            optional(:push_config).hash do
              optional(:endpoint) { str? }
              optional(:create).hash do
                required(:strategy) { str? }
              end
              optional(:update).hash do
                required(:strategy) { str? }
              end
              optional(:delete).hash do
                required(:strategy) { str? }
              end
            end
            optional(:refresh_config).hash do
              optional(:endpoint) { str? }
              required(:strategy) { str? }
            end
          end
        end

        rule('config.push_config.endpoint').validate(:dc_class)
        rule('config.refresh_config.endpoint').validate(:dc_class)

        rule('config.push_config.create.strategy').validate(:dc_module)
        rule('config.push_config.update.strategy').validate(:dc_module)
        rule('config.push_config.delete.strategy').validate(:dc_module)

        rule('config.refresh_config.strategy').validate(:dc_module)
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
