# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GooglePlaces
      module Keywords
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
            .unwind("$dump.#{locale}.types")
            .project(
              "dump.#{locale}.id": "$dump.#{locale}.types",
              "dump.#{locale}.classification": "$dump.#{locale}.types"
            ).group(
              _id: "$dump.#{locale}.id",
              :dump.first => '$dump'
            ).pipeline)
        end

        def extract_data(raw_data)
          {
            external_id: "GooglePlaces - Tags - #{raw_data['classification']}",
            name: raw_data['classification']
          }
        end
      end
    end
  end
end
