module DataCycleCore
  module Generic
    module MediaArchive
      module ImportKeywords
        def import_data(**options)
          @tree_label = options.dig(:import, :tree_label) || 'MediaArchive - Tags'

          # dummy variables to please the import machinery ... not used in this strategy
          @target_type = DataCycleCore::Place
          @data_template = DataCycleCore::Place.find_by(template: true).template_name

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, template, locale, **options)
          I18n.with_locale(locale) do
            keywords = raw_data['keywords'] || []
            keywords.each do |item|
              import_classification(
                {
                  name: item,
                  external_id: "MedienArchive - keyword - #{item}",
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
