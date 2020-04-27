# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module ImportExternalSystems
      def self.import_all(validation: true, external_system_path: nil)
        # update all existing Systems with not responding host
        ActiveRecord::Base.connection.execute("UPDATE external_systems SET credentials = jsonb_set(credentials, '{host}', '\"http://localhost\"'::jsonb, false)")

        errors = {}
        external_system_path ||= DataCycleCore.external_systems_path
        if external_system_path.blank?
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
            external_system.identifier = data['identifier'] || data['name']
            external_system.credentials = data['credentials']
            external_system.config = data['config']
            external_system.default_options = data['default_options']
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
    end
  end
end
