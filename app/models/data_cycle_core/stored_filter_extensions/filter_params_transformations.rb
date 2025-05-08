# frozen_string_literal: true

module DataCycleCore
  module StoredFilterExtensions
    module FilterParamsTransformations
      extend ActiveSupport::Concern

      private

      def apply_filter_parameters
        parameters&.each do |filter|
          t = filter['t'].dup
          t.prepend(DataCycleCore::Type::StoredFilter::Parameters::FILTER_PREFIX[filter['m']].to_s)
          t.concat('_with_subtree') if filter['t'].in?(['classification_alias_ids', 'not_classification_alias_ids'])

          next apply_union_filter(filter['v']) if t == 'union'

          next unless query.respond_to?(t)

          if query.method(t)&.parameters&.size == 3
            self.query = query.send(t, filter['v'], filter['q'].presence, filter['n'].presence)
          elsif query.method(t)&.parameters&.size == 2
            self.query = query.send(t, filter['v'], filter['q'].presence || filter['n'].presence)
          else
            self.query = query.send(t, filter['v'])
          end
        end
      end

      def apply_union_filter(filters)
        all_filters = []

        filters.each do |filter|
          union_sf = DataCycleCore::StoredFilter.new(language:)
          union_sf.parameters = Array.wrap(filter)
          union_sf.apply(skip_ordering: true)

          all_filters += [union_sf.apply(skip_ordering: true)]
        end

        self.query = query.union_filter(all_filters)
      end
    end
  end
end
