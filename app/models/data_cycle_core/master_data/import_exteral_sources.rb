module DataCycleCore
  module MasterData
    module ImportExternalSources
      def self.import_all(validation: true)
        errors = {}
        file_names = Dir[DataCycleCore.external_sources_path + '*.yml']
        file_names.each do |file_name|
          data = YAML.safe_load(File.open(file_name))
          error = validation ? validate(data) : nil
          if error.blank?
            puts "validation was ok --> writing data to ExternalSource"
            # import_data
            # external_source = DataCycleCore::ExternalSource.find_or_initialize_by(name: data['name'])
            # external_source.credentials = data['credentials']
            # external_source.config = data['config']
            # external_source.save
          else
            errors[data['name']] = error
          end
        end
        return errors
      rescue StandardError => e
        puts "could not access the YML File #{file_name}"
        puts e.message
        puts e.backtrace
      end

      def self.validate(data_hash)
        errors = {}
        errors = validate_header(data_hash)
        errors['import_config'] = {}
        errors['download_config'] = {}
        import_config = data_hash.dig('config', 'import_config') || {}
        download_config = data_hash.dig('config', 'download_config') || {}
        import_config.each do |key, value|
          errors['import_config'][key] = validate_import_item(value)
        end
        download_config.each do |key, value|
          errors['download_config'][key] = validate_download_item(value)
        end
        errors
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
          end

          required(:name) { :str? }
          required(:credentials)
          required(:config).schema do
            required(:download) { :str? & :class? }
            required(:download_config)
            required(:import) { :str? & :class? }
            required(:import_config)
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
          end

          required(:sorting) { :int? }
          required(:source_type) { :str? }
          required(:endpoint) { :str? & :class? }
          required(:download_strategy) { :str? & :module? }
          required(:logging_strategy) { :str? & :module? }
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
          end

          required(:sorting) { :int? }
          required(:source_type) { :str? }
          required(:import_strategy) { :str? & :module? }
          required(:data_template) { :str? }
          required(:target_type) { :str? & :class? }
          required(:logging_strategy) { :str? & :logger? }
        end
      end
    end
  end
end
