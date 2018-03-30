module DataCycleCore
  module Generic
    module Eyebase
      module ImportKeywords
        def import_data(**options)
          @tree_label = options.dig(:import, :tree_label) || 'Eyebase - Tags'

          # dummy variables to please the import machinery ... not used in this strategy
          @target_type = DataCycleCore::Place
          @data_template = DataCycleCore::Place.find_by(template: true).template_name

          @eyebase_get_keywords = DataCycleCore::Generic::Transformations::Transformations.eyebase_get_keywords

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale.to_s}.mediaassettype": '501')
        end

        def process_content(raw_data, template, locale)
          I18n.with_locale(locale) do
            keywords = extract_keywords(raw_data)
            keywords.each do |item|
              import_classification({ name: item, external_id: "Eyebase - Tag - #{item}", tree_name: @tree_label })
            end
          end
        end

        def extract_keywords(raw_data)
          @eyebase_get_keywords.call(raw_data)['keywords']
        end
      end
    end
  end
end
