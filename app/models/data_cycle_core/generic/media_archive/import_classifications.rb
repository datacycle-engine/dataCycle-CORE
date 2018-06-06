# frozen_string_literal: true

# TODO: check if this is still used!!
module DataCycleCore
  module Generic
    module MediaArchive
      module ImportClassifications
        def import_data(**options)
          import_classifications(
            @source_type,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            ->(_, _, _) { [] },
            ->(_) { nil },
            method(:extract_data).to_proc,
            **options
          )
        end

        protected

        def load_root_classifications(mongo_item, locale)
          mongo_item.collection.aggregate(mongo_item.where(:_id.ne => nil)
            .unwind("$dump.#{locale}.#{@options.dig(:import, :classification_attribute)}")
            .project(
              "dump.#{locale}.id": "$dump.#{locale}.#{@options.dig(:import, :classification_attribute)}",
              "dump.#{locale}.classification": "$dump.#{locale}.#{@options.dig(:import, :classification_attribute)}"
            ).group(
              _id: "$dump.#{locale}.id",
              :dump.first => '$dump'
            ).pipeline)
        end

        def extract_data(raw_data)
          {
            external_id: "MedienArchive - #{@options.dig(:import, :classification_attribute).singularize} - #{raw_data['classification']}",
            name: raw_data['classification']
          }
        end
      end
    end
  end
end
