# frozen_string_literal: true

module DataCycleCore
  module StoredFilterExtensions
    module FilterParamsTransformations
      extend ActiveSupport::Concern

      private

      def apply_filter_parameters!
        parameters&.each do |filter|
          next if cached_result? && ['uf', 'u'].exclude?(filter['c']) # only apply user filters on cached results

          t = filter['t'].dup
          t.prepend(DataCycleCore::Type::StoredFilter::Parameters::FILTER_PREFIX[filter['m']].to_s)
          t.concat('_with_subtree') if filter['t'].in?(['classification_alias_ids', 'not_classification_alias_ids'])

          next apply_union_filter!(filter['v']) if t == 'union'

          next unless query.respond_to?(t)

          self.query = if query.method(t)&.parameters&.size == 3
                         query.send(t, filter['v'], filter['q'].presence, filter['n'].presence)
                       elsif query.method(t)&.parameters&.size == 2
                         query.send(t, filter['v'], filter['q'].presence || filter['n'].presence)
                       else
                         query.send(t, filter['v'])
                       end
        end
      end

      def apply_union_filter!(filters)
        all_filters = []

        filters.each do |filter|
          union_sf = DataCycleCore::StoredFilter.new(language:)
          union_sf.parameters = Array.wrap(filter)

          all_filters += [union_sf.cached(cached_result).apply_nested]
        end

        self.query = query.union_filter(all_filters)
      end
    end
  end
end
