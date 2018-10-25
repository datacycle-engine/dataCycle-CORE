# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Type
      module CreativeWork
        private

        def find_children(id)
          query = join_creative_work
          query.where(thing[:is_part_of].eq(id))
        end

        def join_creative_work
          Arel::SelectManager.new
            .project(search[:content_data_id])
            .from(search)
            .join(thing)
            .on(search[:content_data_id].eq(thing[:id]).and(search[:content_data_type].eq(quoted('DataCycleCore::Thing'))))
        end

        def creative_work
          DataCycleCore::Thing.arel_table
        end
      end
    end
  end
end
