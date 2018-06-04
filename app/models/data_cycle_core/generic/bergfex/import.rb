# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Import
        def import_data(**options)
          @data_template = options[:import][:data_template] || 'See'
          import_contents(@source_type, @target_type, method(:load_contents).to_proc, method(:process_content).to_proc, **options)
        end

        def load_contents(mongo_item, locale)
          mongo_item.where("dump.#{locale}": { '$exists' => true })
        end

        def process_content(raw_data, _template, locale)
          I18n.with_locale(locale) do
            create_or_update_content(
              DataCycleCore::Place,
              load_template(DataCycleCore::Place, @data_template),
              extract_data(raw_data).with_indifferent_access
            )
          end
        end

        def extract_data(raw_data)
          raw_data.nil? ? {} : DataCycleCore::Generic::Common::Transformations.bergfex_to_see.call(raw_data)
        end
      end
    end
  end
end
