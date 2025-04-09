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
        'proximity.occurrence.eventSchedule' => 'sort_by_proximity_value',
        'proximity.occurrence.openingHoursSpecification' => 'sort_by_proximity_value',
        'proximity.occurrence.dc:diningHoursSpecification' => 'sort_by_proximity_value',
        'proximity.occurrence.hoursAvailable' => 'sort_by_proximity_value',
        'proximity.occurrence.validitySchedule' => 'sort_by_proximity_value',
        'proximity.in_occurrence' => 'sort_by_proximity_value'
      }.freeze

      def apply_sorting_from_parameters(filters:, sort_params:)
        self.sort_parameters ||= []
        sort_by_proximity_value(filters)&.then { |v| sort_parameters.unshift(v) }
        sort_proximity_geographic_value(filters)&.then { |v| sort_parameters.unshift(v) }
        sort_fulltext_value(filters)&.then { |v| sort_parameters.unshift(v) }

        sort_parameters.unshift(*sort_params) if sort_params.present?

        self
      end

      def apply_sorting_from_api_parameters(full_text_search:, raw_query_params: {})
        self.sort_parameters ||= []
        DataCycleCore::ApiService.order_value_from_params('proximity.inTime', full_text_search, raw_query_params).presence&.then { |v| sort_parameters.unshift({ 'm' => 'by_proximity', 'o' => 'ASC', 'v' => v}) }
        DataCycleCore::ApiService.order_value_from_params('proximity.geographic', full_text_search, raw_query_params).presence&.then { |v| sort_parameters.unshift({ 'm' => 'proximity_geographic', 'o' => 'ASC', 'v' => v }) }
        sort_parameters.unshift({ 'm' => 'fulltext_search', 'o' => 'DESC', 'v' => full_text_search }) if full_text_search.present?

        raw_query_params&.dig(:sort)&.split(/,(?![^\(]*\))/)&.reverse_each do |sort|
          key, order, order_value = DataCycleCore::ApiService.order_key_with_value(sort)
          value = DataCycleCore::ApiService.order_value_from_params(key, full_text_search, raw_query_params)

          if value.blank? && SORT_VALUE_API_MAPPING.key?(key) && method(SORT_VALUE_API_MAPPING[key])&.parameters&.size == 1
            value = send(SORT_VALUE_API_MAPPING[key], parameters)&.dig('v')
          elsif value.blank? && SORT_VALUE_API_MAPPING.key?(key) && method(SORT_VALUE_API_MAPPING[key])&.parameters&.size == 2
            value = send(SORT_VALUE_API_MAPPING[key], parameters, order_value)&.dig('v')
          end

          if DataCycleCore::Feature::Sortable.available_advanced_attribute_options.key?(key.underscore)
            value = key.underscore
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

        lon, lat = geo.split(',').map(&:to_f)

        return unless lon.present? && lat.present?

        { 'm' => 'proximity_geographic_with', 'o' => 'ASC', 'v' => [lon, lat] }
      end

      def sort_by_proximity_value(params, value = nil)
        i_config = params&.find { |f| f['t'] == 'in_schedule' }
        min, max = value&.split(',')&.map(&:strip)
        return if i_config.blank? && min.blank? && max.blank?

        if min.present? || max.present?
          i_value = { 'min' => min, 'max' => max, 'relation' => i_config&.dig('n')}.compact_blank
          q = nil
        else
          i_value = i_config&.dig('v')&.merge('relation' => i_config&.dig('n'))&.compact_blank
          q = i_config&.dig('q')
        end

        return if i_value.blank?

        { 'm' => 'by_proximity', 'o' => 'ASC', 'v' => { 'q' => q, 'v' => i_value } }
      end

      def transform_order_hash(sort_hash, watch_list)
        return sort_hash['m'].gsub('advanced_attribute_', ''), 'sort_advanced_attribute' if sort_hash['m'].starts_with?('advanced_attribute_')
        return watch_list.id, 'sort_collection_manual_order' if sort_hash['m'] == 'default' && watch_list&.manual_order

        schedule_proximity_prefixes = ['proximity_occurrence_', 'proximity_inTime_', 'proximity_inT_occurrence_']
        schedule_proximity_prefixes.each do |prefix|
          next unless sort_hash['m'].start_with?(prefix)
          sort_value = { 'relation' => sort_hash['m'].gsub(prefix, '') }
          sort_value = sort_value.merge(sort_hash['v']) if sort_hash.key?('v')
          return sort_value, 'sort_proximity_occurrence'
        end

        return sort_hash['v'].dup, "sort_#{sort_hash['m']}"
      end

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
