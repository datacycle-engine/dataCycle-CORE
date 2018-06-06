# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Import
        def import_data(**options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale.to_s}.mediaassettype.text": '501')
        end

        def process_content(raw_data, locale = 'de')
          I18n.with_locale(locale) do
            process_media_asset(raw_data, options.dig(:import, :transformations, :media_asset))
          end
        end

        def process_media_asset(raw_data, config)
          type = config.dig('content_type').constantize || DataCycleCore::CreativeWork
          template = config.dig(:template) || 'Bild'
          default_values = {}
          default_values = load_default_values(config.dig(:default_values)) if config.dig(:default_values).present?

          create_or_update_content(
            type,
            load_template(type, template),
            default_values.merge(
              DataCycleCore::Generic::Eyebase::Transformations
              .eyebase_to_bild(external_source.id)
              .call(raw_data)
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
