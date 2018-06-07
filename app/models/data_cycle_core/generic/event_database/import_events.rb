# frozen_string_literal: true

module DataCycleCore
  module Generic
    module EventDatabase
      module ImportEvents
        include DataCycleCore::Generic::EventDatabase::Processing

        def import_data(**options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists': true })
        end

        def process_content(raw_data, locale)
          I18n.with_locale(locale) do
            process_image(raw_data, options.dig(:import, :transformations, :image))
            process_place(raw_data, options.dig(:import, :transformations, :place))
            process_event(raw_data, options.dig(:import, :transformations, :event))
          end
        end
      end
    end
  end
end
