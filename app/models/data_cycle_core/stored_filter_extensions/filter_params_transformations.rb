# frozen_string_literal: true

module DataCycleCore
  module StoredFilterExtensions
    module FilterParamsTransformations
      extend ActiveSupport::Concern

      private

      def apply_filter_parameters!
        # when cached, base parameters are already baked into the cached set (rebuilt from `parameters`),
        # so skip them here; apply them live only on a cache miss.
        parameters&.each { |filter| apply_single_filter!(filter) } unless cached_result?

        # user filters live outside `parameters` (see StoredFilter#user_filter_parameters) and are always
        # applied live on top of the base query, including cached results. Defaults to `[]`, never nil.
        user_filter_parameters.each { |filter| apply_single_filter!(filter) }
      end

      def apply_single_filter!(filter)
        t = filter['t'].dup
        t.prepend(DataCycleCore::Type::StoredFilter::Parameters::FILTER_PREFIX[filter['m']].to_s)
        t.concat('_with_subtree') if filter['t'].in?(['classification_alias_ids', 'not_classification_alias_ids'])

        return apply_union_filter!(filter['v']) if t == 'union'

        return unless query.respond_to?(t)

        self.query = if query.method(t)&.parameters&.size == 3
                       query.send(t, filter['v'], filter['q'].presence, filter['n'].presence)
                     elsif query.method(t)&.parameters&.size == 2
                       query.send(t, filter['v'], filter['q'].presence || filter['n'].presence)
                     else
                       query.send(t, filter['v'])
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
