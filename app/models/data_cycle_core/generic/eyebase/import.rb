# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Import
        include DataCycleCore::Generic::Eyebase::Processing

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
      end
    end
  end
end
