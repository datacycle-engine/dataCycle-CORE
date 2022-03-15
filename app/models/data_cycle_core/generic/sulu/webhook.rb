# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Sulu
      class Webhook < DataCycleCore::Generic::Common::Webhook
        def update(raw_data, _external_system)
          validator = Contract.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}
          return { error: errors } if errors.present?
          data = DataCycleCore::Generic::DataCycleApiV4::Transformations.transformation.call(raw_data)

          init_logging do |logging|
            errors = update_content(data: data)
            errors = nil if errors.blank?
            if errors.present?
              logging.error('update', data['id'], raw_data, errors)
            else
              logging.info("Update   Thing: #{data['id']}", "transformed_data: #{data}")
            end
          end
          errors.present? ? { error: errors } : { update: data['id'] }
        end

        private

        def update_content(data:)
          thing = DataCycleCore::Thing.find(data['id'])
          # transform  url -> sulu_url
          data['sulu_url'] = data.delete('url')
          thing.set_data_hash(data_hash: data, partial_update: true, prevent_history: false)
          thing.errors.messages
        end

        def init_logging
          logging = DataCycleCore::Generic::GenericObject.new.init_logging(:sulu_external_system)
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
        end
      end
    end
  end
end
