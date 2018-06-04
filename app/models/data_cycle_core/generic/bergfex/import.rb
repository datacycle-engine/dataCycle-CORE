# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Import
        def import_data(**options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, locale)
          I18n.with_locale(locale) do
            process_lakes(raw_data, options.dig(:import, :transformations, :lake))
          end
        end

        def process_lakes(raw_data, config)
          type = config.dig('content_type').constantize || DataCycleCore::Place
          template = config.dig(:template) || 'See'
          default_values = {}
          default_values = load_default_values(config.dig(:default_values)) if config.dig(:default_values).present?

          create_or_update_content(
            type,
            load_template(type, template),
            default_values.merge(
              DataCycleCore::Generic::Bergfex::Transformations
              .bergfex_to_see
              .call(raw_data)
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
