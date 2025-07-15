# frozen_string_literal: true

module DataCycleCore
  module StoredFilterExtensions
    module SortParamTransformations
      extend ActiveSupport::Concern

      SORT_VALUE_API_MAPPING = {
        'similarity' => 'sort_fulltext_value',
        'proximity.geographic' => 'sort_proximity_geographic_value',
        'proximity.geographic_with' => 'sort_proximity_geographic_with_value',
        'proximity.inTime' => 'sort_by_proximity_value',
        'proximity.occurrence' => 'sort_by_proximity_value',
        'proximity.in_occurrence' => 'sort_by_proximity_value',
        'proximity.in_occurrence_with_distance' => 'sort_by_in_occurrence_with_distance',
        'proximity.in_occurrence_with_distance_pia' => 'sort_by_in_occurrence_with_distance'
      }.freeze

      def apply_sorting_from_parameters(filters:, sort_params:)
        self.sort_parameters ||= []
        sort_by_proximity_value(filters)&.then { |v| sort_parameters.unshift(v) }
        sort_proximity_geographic_value(filters)&.then { |v| sort_parameters.unshift(v) }
        sort_fulltext_value(filters)&.then { |v| sort_parameters.unshift(v) }

        sort_parameters.unshift(*sort_params) if sort_params.present?

        self
      end

      # Calls Methods sort_fulltext_value, sort_proximity_geographic_value, sort_by_proximity_value for sort-attributes via send
      def apply_sorting_from_api_parameters(full_text_search:, raw_query_params: {})
        self.sort_parameters ||= []
        DataCycleCore::ApiService.order_value_from_params('proximity.inTime', full_text_search, raw_query_params).presence&.then { |v| sort_parameters.unshift({ 'm' => 'by_proximity', 'o' => 'ASC', 'v' => v}) }
        DataCycleCore::ApiService.order_value_from_params('proximity.geographic', full_text_search, raw_query_params).presence&.then { |v| sort_parameters.unshift({ 'm' => 'proximity_geographic', 'o' => 'ASC', 'v' => v }) }
        sort_parameters.unshift({ 'm' => 'fulltext_search', 'o' => 'DESC', 'v' => full_text_search }) if full_text_search.present?

        raw_query_params&.dig(:sort)&.split(/,(?![^\(]*\))/)&.reverse_each do |sort|
          key, order, order_value = DataCycleCore::ApiService.order_key_with_value(sort)
          if SORT_VALUE_API_MAPPING.key?(key) && method(SORT_VALUE_API_MAPPING[key])&.parameters&.size == 1
            value = send(SORT_VALUE_API_MAPPING[key], parameters)&.dig('v')
          elsif SORT_VALUE_API_MAPPING.key?(key) && method(SORT_VALUE_API_MAPPING[key])&.parameters&.size == 2
            value = send(SORT_VALUE_API_MAPPING[key], parameters, order_value)&.dig('v')
          end

          filter_order = DataCycleCore::ApiService.order_value_from_params(key, full_text_search, raw_query_params)
          value = value.blank? ? filter_order : merge_api_filter_params(value, filter_order, SORT_VALUE_API_MAPPING[key])

          if (advanced_key = DataCycleCore::Feature::Sortable.available_advanced_attribute_for_key(key)).present?
            value = advanced_key
            key = 'advanced_attribute'
          end

          value = order_value if value.blank? && order_value.present?

          sort_parameters.unshift({
            'm' => key.underscore_blanks,
            'o' => order,
            'v' => value.presence
          }.compact)
        end

        self
      end

      private

      def sort_fulltext_value(params)
        return if params.blank?

        params&.find { |f| f['t'] == 'fulltext_search' }&.dig('v')&.then { |v| { 'm' => 'fulltext_search', 'o' => 'DESC', 'v' => v } }
      end

      def sort_proximity_geographic_value(params)
        return if params.blank?

        params&.find { |f| f['t'] == 'geo_filter' && f['q'] == 'geo_radius' }&.dig('v')&.then { |v| { 'm' => 'proximity_geographic', 'o' => 'DESC', 'v' => v.values_at('lon', 'lat', 'distance') } }
      end

      def sort_proximity_geographic_with_value(_params, geo)
        return if geo.blank?

        parsed_params = parse_sort_params(geo, __method__)
        lon = parsed_params['lon']
        lat = parsed_params['lat']

        return unless lon.present? && lat.present?

        { 'm' => 'proximity_geographic_with', 'o' => 'ASC', 'v' => [lon, lat] }
      end

      def sort_by_proximity_value(params, value = nil)
        i_config = params&.find { |f| f['t'] == 'in_schedule' }
        parsed_params = parse_sort_params(value, __method__)
        min = parsed_params&.dig('start')
        max = parsed_params&.dig('end')
        return if i_config.blank? && min.blank? && max.blank? && parsed_params&.dig('sort_attr').blank?

        relation = parsed_params&.dig('sort_attr').presence || i_config&.dig('n')
        if min.present? || max.present?
          i_value = { 'min' => min, 'max' => max}.compact_blank
          q = nil
        else
          i_value = i_config&.dig('v')&.compact_blank
          q = i_config&.dig('q')
        end
        i_value ||= {}
        i_value = i_value.merge('relation' => relation).compact_blank if relation.present?
        return if i_value.blank?

        { 'm' => 'by_proximity', 'o' => 'ASC', 'v' => { 'q' => q, 'v' => i_value } }
      end

      def sort_by_in_occurrence_with_distance(_params, value = nil)
        parsed_params = parse_sort_params(value, __method__)

        return if parsed_params.blank?

        coords = []
        coords = [parsed_params['lon'], parsed_params['lat']] if parsed_params['lon'].present? || parsed_params['lat'].present?

        i_value = [coords]
        schedule = {}
        schedule['in'] = { 'min' => parsed_params['start'], 'max' => parsed_params['end'] } if parsed_params['start'].present? || parsed_params['end'].present?
        schedule['relation'] = parsed_params['sort_attr'] if parsed_params['sort_attr'].present?

        i_value << schedule if schedule.present?
        { 'v' => i_value }
      end

      def parse_sort_params(params, sort_key = :sort_by_proximity_value)
        return if params.blank?
        sort_params = params&.split(',', -1)&.map { |v| v&.strip.presence }

        return {'lon' => sort_params[0], 'lat' => sort_params[1]} if sort_key == :sort_proximity_geographic_with_value && sort_params.size == 2
        return {'start' => sort_params[0], 'end' => sort_params[1], 'sort_attr' => sort_params[2]} if sort_key == :sort_by_proximity_value && sort_params.size == 3
        return {'lon' => sort_params[0], 'lat' => sort_params[1], 'start' => sort_params[2], 'end' => sort_params[3], 'sort_attr' => sort_params[4]} if sort_key == :sort_by_in_occurrence_with_distance && sort_params.size == 5

        result = {'lon' => nil, 'lat' => nil, 'start' => nil, 'end' => nil, 'sort_attr' => nil}
        sort_params.each do |param|
          key, val = param.to_s.split(':', 2).map(&:strip)
          result[key] = val if result.key?(key)
          result['sort_attr'] = val if "sort_#{key}" == 'sort_attr'
        end

        result
      end

      def merge_api_filter_params(sort_params, filter_params, sort_key)
        return merge_api_in_occurrence_with_distance_default_params(sort_params, filter_params) if sort_key == 'sort_by_in_occurrence_with_distance'

        sort_params['v'] = merge_api_schedule_params(sort_params['v'], filter_params) if sort_key == 'sort_by_proximity_value'
        sort_params
      end

      def merge_api_in_occurrence_with_distance_default_params(sort_params, filter_params)
        return sort_params if filter_params.nil?

        [
          sort_params[0].nil? || sort_params[0].all?(&:nil?) ? filter_params[0] : sort_params[0],
          merge_api_schedule_params(sort_params[1], filter_params[1])
        ]
      end

      def merge_api_schedule_params(sort_schedule, filter_schedule)
        return sort_schedule if filter_schedule.blank?
        return filter_schedule if sort_schedule.blank?

        sort_min, sort_max = DataCycleCore::Filter::Common::Date.date_from_filter_object(
          sort_schedule&.dig('in') || sort_schedule
        )
        filter_min, filter_max = DataCycleCore::Filter::Common::Date.date_from_filter_object(
          filter_schedule&.dig('in') || filter_schedule
        )

        min = [sort_min, filter_min].compact_blank.max
        max = [sort_max, filter_max].compact_blank.min
        max = nil if min.present? && max.present? && min > max

        {
          'from' => min,
          'until' => max,
          'relation' => sort_schedule['relation'] || filter_schedule['relation']
        }.compact_blank
      end

      def transform_order_hash(sort_hash, watch_list)
        return sort_hash['m'].gsub('advanced_attribute_', ''), 'sort_advanced_attribute' if sort_hash['m'].starts_with?('advanced_attribute_')
        return watch_list.id, 'sort_collection_manual_order' if sort_hash['m'] == 'default' && watch_list&.manual_order

        return sort_hash['v'].dup, "sort_#{sort_hash['m']}"
      end

      # Calls sort_advanced_attribute, sort_collection_manual_order, sort_proximity_occurrence,
      # sort_proximity_in_occurrence_with_distance, sort_proximity_in_occurrence_with_distance_pia, ...
      def apply_order_parameters(watch_list)
        self.sort_parameters = [{ 'm' => 'default' }] if sort_parameters.blank?
        self.query = query.reset_sort

        sort_parameters.each do |sort|
          sort_value, sort_method_name = transform_order_hash(sort, watch_list)

          next unless query.respond_to?(sort_method_name)
          if query.method(sort_method_name)&.parameters&.size == 2
            ordered_query = query.send(sort_method_name, sort['o'].presence, sort_value.presence)
          elsif query.method(sort_method_name)&.parameters&.size == 1
            ordered_query = query.send(sort_method_name, sort['o'].presence)
          end

          next if query == ordered_query

          self.query = ordered_query
          self.sort_parameters = [sort]
          break
        end
      end
    end
  end
end
