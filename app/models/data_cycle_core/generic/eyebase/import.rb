module DataCycleCore
  module Generic
    module Eyebase
      module Import
        def import_data(**options)
          @eyebase_transformation = DataCycleCore::Generic::Transformations::Transformations.eyebase_to_bild(external_source.id)

          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        protected

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale.to_s}.mediaassettype": '501')
        end

        def process_content(raw_data, template, locale = 'de')
          I18n.with_locale(locale) do
            create_or_update_content(
              @target_type,
              load_template(@target_type, @data_template),
              extract_image_data(raw_data).with_indifferent_access
            )
          end
        end

        def extract_image_data(raw_data)
          raw_data.nil? ? {} : @eyebase_transformation.call(raw_data)
        end
      end
    end
  end
end
