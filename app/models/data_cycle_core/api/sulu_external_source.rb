# frozen_string_literal: true

module DataCycleCore
  module Api
    class SuluExternalSource < DataCycleCore::Api::GenericExternalSource
      def update(raw_data)
        errors = data_validator.call(raw_data.deep_symbolize_keys).errors || {}
        return { error: errors } if errors.present?
        data = DataCycleCore::Generic::DataCycleApiV4::Transformations.transformation.call(raw_data)
        init_logging do |logging|
          errors = update_content(data: data)
          errors = nil if errors.dig('error').blank?
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
        thing.set_data_hash(data_hash: data, partial_update: true, prevent_history: false)
      end

      def data_validator
        Dry::Validation.Schema do
          required(:@id) { str? }
          required(:@type) { str? }
          required(:url) { str? }
        end
      end

      def init_logging
        logging = DataCycleCore::Generic::GenericObject.new.init_logging(:sulu_external_source)
        yield(logging)
      ensure
        logging.close if logging.respond_to?(:close)
      end
    end
  end
end