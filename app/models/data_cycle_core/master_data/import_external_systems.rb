# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSystems
      def self.import_all(validation: true, external_system_path: nil)
        errors = {}
        external_system_path ||= DataCycleCore.external_systems_path
        if external_system_path.blank?
          puts '###### external systems not found'
          return
        end

        file_names = Dir[external_system_path + '*.yml']
        file_names.each do |file_name|
          data = YAML.safe_load(File.open(file_name))
          error = validation ? validate(data.deep_symbolize_keys) : nil
          if error.blank?
            external_system = DataCycleCore::ExternalSystem.find_or_initialize_by(name: data['name'])
            external_system.credentials = data['credentials']
            external_system.config = data['config']
            external_system.default_options = data['default_options']
            external_system.save

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

      def self.validate(data_hash)
        errors = validate_header.call(data_hash.deep_symbolize_keys).errors || {}
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
          optional(:default_options).schema do
            optional(:locales).each { str? }
          end
        end
      end
    end
  end
end