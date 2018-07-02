# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSources
      def self.import_all(validation: true)
        errors = {}
        file_names = Dir[DataCycleCore.external_sources_path + '*.yml']
        file_names.each do |file_name|
          data = YAML.safe_load(File.open(file_name))
          error = validation ? validate(data.deep_symbolize_keys) : nil
          if error.blank?
            external_source = DataCycleCore::ExternalSource.find_or_initialize_by(name: data['name'])
            external_source.credentials = data['credentials']
            external_source.config = data['config']
            external_source.default_options = data['default_options']
            external_source.save

            check_for_use_case(external_source.id)
          else
            errors[data['name']] = error
          end
        end
        errors
      rescue StandardError => e
        puts "could not access the YML File #{file_name}"
        puts e.message
        puts e.backtrace
      end

      def self.check_for_use_case(external_source_id)
        user = DataCycleCore::User.find_by(email: 'admin@pixelpoint.at') || DataCycleCore::User.find_by(email: 'admin@datacycle.at')
        use_case = DataCycleCore::UseCase.find_or_initialize_by(
          user_id: user.id,
          external_source_id: external_source_id
        )
        use_case.save unless use_case.persisted?
      rescue StandardError => e
        puts 'could not find the super_admin user'
        puts e.message
        puts e.backtrace
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

            def self.messages
              super.merge(
                en: {
                  errors: {
                    class?: 'the string given does not specify a valid ruby class.'
                  }
                }
              )
            end
          end

          required(:name) { str? }
          required(:credentials) { hash? }
          optional(:api_strategy) { str? & class? }
          optional(:default_options).schema do
            optional(:locales).each { str? }
          end
          required(:config).schema do
            required(:download_config) { hash? }
            required(:import_config) { hash? }
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
              temp = Class.new.instance_eval(value) rescue false
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
              temp = Class.new.instance_eval(value) rescue false
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
