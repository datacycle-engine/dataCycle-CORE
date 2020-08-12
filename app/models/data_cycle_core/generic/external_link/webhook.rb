# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ExternalLink
      class Webhook < DataCycleCore::Generic::Common::Webhook
        def update(raw_data)
          validator = Contract.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}
          return { error: errors } if errors.present?
          data = DataCycleCore::Generic::ExternalLink::Transformations.transformation.call(raw_data)

          init_logging do |logging|
            errors = update_sync(data: data, external_system_id: raw_data.dig('data_cycle_external_system_id'))
            errors = nil if errors.blank?
            if errors.present?
              logging.error('update', data['id'], raw_data, errors)
            else
              logging.info("Update   Thing: #{data['id']}", "transformed_data: #{data}")
            end
          end
          errors.present? ? { error: errors } : { update: "#{data['id']} (#{data.dig('external_system_syncs').map { |i| i['external_key'] }.join(', ')})" }
        end

        def delete(raw_data)
          validator = Contract.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}
          return { error: errors } if errors.present?
          data = DataCycleCore::Generic::ExternalLink::Transformations.transformation.call(raw_data)

          init_logging do |logging|
            errors = delete_sync(data: data, external_system_id: raw_data.dig('data_cycle_external_system_id'))
            errors = nil if errors.blank?
            if errors.present?
              logging.error('update', data['id'], raw_data, errors)
            else
              logging.info("Update   Thing: #{data['id']}", "transformed_data: #{data}")
            end
          end
          errors.present? ? { error: errors } : { delete: "#{data['id']} (#{data.dig('external_system_syncs').map { |i| i['external_key'] }.join(', ')})" }
        end

        private

        def update_sync(data:, external_system_id:)
          return ["Data with id=#{data['id']} not found!"] if DataCycleCore::Thing.where(id: data['id']).blank?
          now = Time.zone.now
          data.dig('external_system_syncs').each do |sync_data|
            sync = DataCycleCore::ExternalSystemSync.find_or_initialize_by(syncable_id: data['id'], syncable_type: 'DataCycleCore::Thing', external_system_id: external_system_id, external_key: sync_data.dig('external_key'))
            sync.data = Hash(sync.data).merge(pull_data: data.merge(updated_at: now), external_key: sync_data.dig('external_key'))
            sync.data['pull_delete_data'] = nil if sync.data.dig('pull_delete_data').present?
            sync.data['external_name'] = sync_data['external_name'] if sync_data['external_name'].present?
            sync.last_pull_at = now
            sync.save!
            sync.last_successful_pull_at = now
            sync.save!
          end
          {}
        end

        def delete_sync(data:, external_system_id:)
          return ["Data with id=#{data['id']} not found!"] if DataCycleCore::Thing.where(id: data['id']).blank?
          data.dig('external_system_syncs').each do |sync_data|
            sync = DataCycleCore::ExternalSystemSync.find_by(syncable_id: data['id'], syncable_type: 'DataCycleCore::Thing', external_system_id: external_system_id, external_key: sync_data.dig('external_key'))
            return ["Nothing to delete for data with id=#{data['id']}, in system with id=#{external_system_id}, external_id: #{sync_data.dig('external_key')}!"] if sync.blank?
            sync.destroy
          end
          {}
        end

        def init_logging
          logging = DataCycleCore::Generic::GenericObject.new.init_logging(:exozet_external_system)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end

      class Contract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:@id) { str? }
          required(:@type) { str? }
          required(:url) { str? }
          optional(:name) { str? }
          optional(:inLanguage) { str? }
          required(:identifier).value(:array, min_size?: 1).each do
            hash do
              required(:@type).value(:string)
              required(:propertyID).value(:string)
              required(:value).value(:string)
            end
          end
        end
      end
    end
  end
end
