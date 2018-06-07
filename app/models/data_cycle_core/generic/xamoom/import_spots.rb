# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module ImportSpots
        include DataCycleCore::Generic::Xamoom::Processing

        def import_data(**options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.all
        end

        def process_content(raw_data, locale)
          I18n.with_locale(locale) do
            process_image(raw_data, options.dig(:import, :transformations, :image))
            process_spot(raw_data, options.dig(:import, :transformations, :spot))
          end
        end
      end
    end
  end
end
