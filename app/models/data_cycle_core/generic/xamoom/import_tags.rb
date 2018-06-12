# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module ImportTags
        def self.import_data(import_object, **options)
          import_contents(method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, locale, options)
          I18n.with_locale(locale) do
            tree_label = options.dig(:import, :transformations, :tags, :tree_label)
            keywords = raw_data.dig('attributes', 'tags') || []
            keywords.each do |item|
              import_classification({ name: item, external_id: "Xamoom - tag - #{item}", tree_name: tree_label })
            end
          end
        end
      end
    end
  end
end
