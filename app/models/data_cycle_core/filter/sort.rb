# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Sort
      def sort_boost(table, ordering)
        return self if table.blank? || ordering.blank?
        reflect(
          @query
            .order(Arel.sql("#{table}.boost #{ordering}"))
        )
      end

      def sort_updated_at(table, ordering)
        return self if table.blank? || ordering.blank?
        reflect(
          @query
            .order(Arel.sql("#{table}.updated_at #{ordering}"))
        )
      end

      def sort_name(table, ordering)
        return self if table.blank? || ordering.blank?
        binding.pry
        reflect(
          @query
            .order(Arel.sql("#{table}.updated_at #{ordering}"))
        )
      end

      def sort_by_proximity(_table, _ordering, value)
        date = date_from_single_value(value) || Time.zone.now
        reflect(
          @query.reorder(
            absolute_date_diff(thing[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
            absolute_date_diff(thing[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
            thing[:start_date]
          )
        )
      end

      def sort_fulltext_search(_table, ordering)
        reflect(
          @query
            .reorder(
              Arel.sql("fulltext_boost #{ordering}"),
              Arel.sql('things.updated_at DESC'),
              Arel.sql('things.id ASC')
            )
        )
      end
    end
  end
end
