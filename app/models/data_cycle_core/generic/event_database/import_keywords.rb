# frozen_string_literal: true

module DataCycleCore
  module Generic
    module EventDatabase
      module ImportKeywords
        def import_data(**options)
          @tree_label = options&.dig(:import, :tree_label) || 'Veranstaltungsdatenbank - Tag'

          # dummy variables to please the import machinery ... not used in this strategy
          @target_type = DataCycleCore::Event
          @data_template = DataCycleCore::Event.find_by(template: true).template_name

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, template, locale, **options)
          I18n.with_locale(locale) do
            keywords = raw_data['tags'] || []
            keywords.each do |item|
              import_classification(
                {
                  name: item,
                  external_id: "Veranstaltungsdatenbank - tags - #{item}",
                  tree_name: @tree_label
                }
              )
            end
          end
        end
      end
    end
  end
end
