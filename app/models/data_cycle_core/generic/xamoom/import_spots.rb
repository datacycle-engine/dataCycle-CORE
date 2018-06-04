# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module ImportSpots
        def import_data(**options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.all
        end

        def process_content(raw_data, locale)
          I18n.with_locale(locale) do
            process_image(raw_data, options.dig(:import, :transformations, :image))
            process_spot(raw_data, options.dig(:import, :transformations, :spot))
          end
        end

        def process_image(raw_data, config)
          raise "Missing configuration for #{self.class} when calling 'process_image', options given: #{config}" if config.blank?

          type = config.dig('content_type').constantize || DataCycleCore::CreativeWork
          template = config.dig(:template) || 'Bild'
          default_values = {}
          default_values = load_default_values(config.dig(:default_values)) if config.dig(:default_values).present?

          create_or_update_content(
            type,
            load_template(type, template),
            default_values.merge(
              DataCycleCore::Generic::Xamoom::Transformations
              .xamoom_to_image
              .call(raw_data['attributes'])
              .merge(external_key: "Xamoom - #{raw_data['id']}")
            ).with_indifferent_access
          )
        end

        def process_spot(raw_data, config)
          raise "Missing configuration for #{self.class} when calling 'process_spot', options given: #{config}" if config.blank?

          type = config.dig('content_type').constantize || DataCycleCore::Place
          data_template = config.dig('template') || 'Örtlichkeit'
          default_values = {}
          default_values = load_default_values(config.dig(:default_values)) if config.dig(:default_values).present?

          create_or_update_content(
            type,
            load_template(type, data_template),
            default_values.merge(
              DataCycleCore::Generic::Xamoom::Transformations
              .xamoom_to_poi(external_source.id)
              .call(raw_data['attributes'])
              .merge(external_key: "Xamoom - #{raw_data['id']}")
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
