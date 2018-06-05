# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module ImportKeywords
        def import_data(**options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale.to_s}.mediaassettype.text": '501')
        end

        def process_content(raw_data, locale)
          I18n.with_locale(locale) do
            tree_label = options.dig(:import, :transformations, :keywords, :tree_label)
            keywords = DataCycleCore::Generic::Eyebase::Transformations.eyebase_get_keywords.call(raw_data).dig('keywords') || []
            keywords.each do |item|
              import_classification({ name: item, external_id: "Eyebase - Tag - #{item}", tree_name: tree_label })
            end
          end
        end
      end
    end
  end
end
