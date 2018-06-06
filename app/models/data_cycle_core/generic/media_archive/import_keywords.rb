# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module ImportKeywords
        def import_data(**options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, locale)
          I18n.with_locale(locale) do
            tree_label = options.dig(:import, :transformations, :keyword, :tree_label)
            keywords = raw_data['keywords'] || []
            keywords.each do |item|
              import_classification(
                {
                  name: item,
                  external_id: "MedienArchive - keyword - #{item}",
                  tree_name: tree_label
                }
              )
            end
          end
        end
      end
    end
  end
end
