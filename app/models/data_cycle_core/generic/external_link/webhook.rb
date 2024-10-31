# frozen_string_literal: true

# this file is only required for tests, it is duplicated in datacycle-connector-legacy

module DataCycleCore
  module Generic
    module ExternalLink
      class Webhook < DataCycleCore::Generic::Common::Webhook
        def update(raw_data, external_system)
          validator = Contract.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}
          return { error: errors } if errors.present?
          data = DataCycleCore::Generic::ExternalLink::Transformations.transformation(external_system.id).call(raw_data)

          init_logging do |logging|
            errors = update_sync(data:, external_system:)

            if errors.present?
              logging.error('update', data['id'], raw_data, errors)
            else
              logging.info("update Thing: #{data['id']}", "transformed_data: #{data}")
            end
          end

          errors.present? ? { error: errors } : { update: "#{data['id']} (#{data.dig('external_system_syncs').pluck(:external_key).join(', ')})" }
        end

        def delete(raw_data, external_system)
          validator = Contract.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}
          return { error: errors } if errors.present?
          data = DataCycleCore::Generic::ExternalLink::Transformations.transformation(external_system.id).call(raw_data)

          init_logging do |logging|
            errors = delete_sync(data:, external_system:)

            if errors.present?
              logging.error('delete', data['id'], raw_data, errors)
            else
              logging.info("delete Thing: #{data['id']}", "transformed_data: #{data}")
            end
          end
          errors.present? ? { error: errors } : { delete: "#{data['id']} (#{data.dig('external_system_syncs').pluck(:external_key).join(', ')})" }
        end

        private

        def update_sync(data:, external_system:)
          return ["Data with id=#{data['id']} not found!"] unless DataCycleCore::Thing.exists?(id: data['id'])
          now = Time.zone.now
          data.dig('external_system_syncs').each do |sync_data|
            sync = external_system.external_system_syncs.find_or_initialize_by(syncable_id: data['id'], syncable_type: 'DataCycleCore::Thing', external_key: sync_data.dig(:external_key), sync_type: 'link')
            sync.data = Hash(sync.data).merge(pull_data: data.merge(updated_at: now))
            sync.data['name'] = sync_data[:name] if sync_data[:name].present?
            sync.data['alternate_name'] = sync_data[:alternate_name] if sync_data[:alternate_name].present?
            sync.status = 'success'
            sync.last_sync_at = now
            sync.last_successful_sync_at = now
            sync.save!
          end

          additional_update_actions(data, external_system) || {}
        end

        def delete_sync(data:, external_system:)
          return ["Data with id=#{data['id']} not found!"] unless DataCycleCore::Thing.exists?(id: data['id'])
          data.dig('external_system_syncs').each do |sync_data|
            sync = external_system.external_system_syncs.find_by(syncable_id: data['id'], syncable_type: 'DataCycleCore::Thing', external_key: sync_data.dig(:external_key), sync_type: 'link')
            return ["Nothing to delete for data with id=#{data['id']}, in system with id=#{external_system.id}, external_id: #{sync_data.dig(:external_key)}!"] if sync.blank?
            sync.destroy!
          end

          additional_delete_actions(data, external_system) || {}
        end

        def init_logging
          logging = DataCycleCore::Generic::GenericObject.init_logging(:exozet_external_system)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end

        def additional_update_actions(data, external_system)
        end

        def additional_delete_actions(data, external_system)
        end
      end

      class Contract < DataCycleCore::MasterData::Contracts::GeneralContract
        schema do
          required(:@id) { str? }
          required(:@type) { str? }
          optional(:url) { str? }
          optional(:inLanguage) { str? }
          required(:identifier).value(:array, min_size?: 1).each do
            hash do
              optional(:name) { str? }
              required(:@type).value(:string)
              required(:propertyID).value(:string)
              required(:value).value(:string)
              optional(:alternateName) { str? }
            end
          end
        end
      end
    end
  end
end
