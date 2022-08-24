# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleApiV4
      class Webhook < DataCycleCore::Generic::Common::Webhook
        include DataCycleCore::Engine.routes.url_helpers

        def create(raw_data, _external_system, current_user)
          return { error: 'no data' } if raw_data.blank?

          type = raw_data['@type']&.delete_prefix('dcls:')

          return { error: 'missing @type' } if type.nil?

          template = DataCycleCore::Thing.find_by(template: true, template_name: type)

          return { error: 'invalid @type' } if template.nil?

          data = transformations(template, current_user).call(raw_data)

          return { error: 'no data' } if data.blank?

          content = DataCycleCore::DataHashService.create_internal_object(template.template_name, data.merge({ local_import: true }), current_user)

          # binding.pry

          return { error: content.errors.messages } unless content.valid?

          {
            meta: {
              thing_id: content.id,
              language: content.translated_locales
            }
          }
        end

        private

        def t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def transformations(template, current_user)
          t(:stringify_keys)
          .>> t(:underscore_keys)
          .>> t(:accept_keys, template.plain_property_names + ['asset'])
          .>> t(:local_asset, 'asset', template.properties_for('asset')&.dig('asset_type'), current_user&.id)
          .>> t(:json_ld_to_translated_data_hash)
        end
      end
    end
  end
end
