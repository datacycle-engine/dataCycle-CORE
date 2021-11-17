# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Amtangee
      class Webhook < DataCycleCore::Generic::Common::Webhook
        def update(raw_data, _external_system)
          validator = ContractUpdate.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}
          return { error: errors } if errors.present?

          id = raw_data.dig('contact', 'vCloudID').downcase
          return { error: "wrong data: #{id} != #{external_key.downcase}" } if id != external_key.downcase

          thing = DataCycleCore::Thing.find_by(id: id)
          return { error: { 'contact' => { 'vCloudID' => ['invalid id'] } } } if thing.blank?
          return { error: 'Data can not be updated, ist has another Owner.' } if thing.external_key.present? || thing.external_source_id.present?

          process_content(thing, raw_data)
        end

        def create(raw_data, _external_system)
          validator = ContractCreate.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}
          return { error: errors } if errors.present?
          return { error: 'External Source can not choose dataCycle ID. (remove attribute category -> vClouID)' } if raw_data.dig('contact', 'vCloudID').present?

          thing_id = DataCycleCore::ExternalSystemSync.find_by(external_system_id: external_source.id, sync_type: 'import', external_key: raw_data.dig('contact', 'id'))&.syncable_id
          return { error: "Data with external ID:#{raw_data.dig('contact', 'id')} already exists with dataCycle ID: #{thing_id}." } if thing_id.present?

          thing = DataCycleCore::DataHashService.create_internal_object('POI', {}, nil)

          response = process_content(thing, raw_data)
          thing.destroy_content if response[:error].present?
          response
        end

        private

        def process_content(thing, raw_data)
          response = {}
          init_logging do |logging|
            data = raw_data.except('format', 'token', 'controller', 'action', 'external_source_id', 'external_key')

            download_config = { source_type: 'things', locales: [:de] }
            unless download_content(download_config: download_config, data: data)
              error = 'something went wrong writing to the MongoDB'
              logging.error('update', thing.id, raw_data, error)
              return { error: error }
            end

            save_time = Time.zone.now
            data_hash = DataCycleCore::Generic::Amtangee::Transformations.to_thing.call(data)
            # partial_update is not recursive
            data_hash['contact_info'] = (data_hash['contact_info'] || {}).reverse_merge(thing.contact_info.to_h)
            data_hash['address'] = (data_hash['address'] || {}).reverse_merge(thing.address.to_h)

            if thing.set_data_hash(data_hash: data_hash, partial_update: true, save_time: save_time)
              thing.add_external_system_data(external_source, nil, 'success', 'import', data.dig('contact', 'id'))
              logging.info('update', thing.id)
              response = { 'datetime' => save_time, 'vCloudID' => thing.id }
            else
              error_msg = thing.errors.messages
              thing.add_external_system_data(external_source, { 'error' => error_msg }, 'error', 'import', data.dig('contact', 'id'))
              logging.error('update', thing.id, raw_data, error)
              response = { error: error_msg }
            end
          end
          response
        end

        def download_content(download_config:, data:)
          return if data.blank?

          full_options = (external_source.default_options || {}).symbolize_keys.merge({ download: download_config.symbolize_keys })
          locales = full_options.dig(:locales) || full_options.dig(:download, :locales) || I18n.available_locales
          download_object = DataCycleCore::Generic::DownloadObject.new(full_options.merge(external_source: external_source, locales: locales))

          DataCycleCore::Generic::Common::DownloadFunctions.dump_raw_data(
            download_object: download_object,
            data_id: ->(s) { s.dig('contact', 'vCloudID').downcase },
            data_name: ->(s) { s.dig('contact', 'name') },
            raw_data: data,
            options: full_options.deep_symbolize_keys
          )
        end

        def init_logging
          logging = DataCycleCore::Generic::GenericObject.new.init_logging(:amtangee_external_system)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end

      class ContractUpdate < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:contact).hash do
            required(:vCloudID) { str? }
            required(:id) { str? }
          end
        end
      end

      class ContractCreate < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:contact).hash do
            required(:id) { str? }
          end
        end
      end
    end
  end
end
