# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module ImportTours
        include DataCycleCore::Generic::OutdoorActive::Processing

        def import_data(**options)
          @source_filter = options.dig(:import, :source_filter) || {}
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where(@source_filter.merge("dump.#{locale}.frontendtype" => 'tour'))
        end

        def process_content(raw_data, locale)
          I18n.with_locale(locale) do
            process_image(raw_data, options.dig(:import, :transformations, :image))
            process_tour(raw_data, options.dig(:import, :transformations, :tour))
          end
        end
      end
    end
  end
end
