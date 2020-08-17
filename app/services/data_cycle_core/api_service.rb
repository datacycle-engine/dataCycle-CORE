# frozen_string_literal: true

module DataCycleCore
  module ApiService
    def list_api_request(contents = nil)
      contents ||= @contents
      json_context = api_plain_context(@language)
      json_contents = contents.map do |item|
        Rails.cache.fetch(api_v4_cache_key(item, @language, @include_parameters, @fields_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
          item.to_api_list
        end
      end
      json_links = api_plain_links(contents)
      list_hash = {
        '@context' => json_context,
        '@graph' => json_contents,
        'links' => json_links
      }
      list_hash['meta'] = api_plain_meta(contents.total_count, contents.total_pages) unless @mode_parameters == 'strict'
      list_hash
    end

    def list_api_deleted_request(contents)
      json_context = api_plain_context(@language)
      json_contents = contents.map do |item|
        Rails.cache.fetch(api_v4_cache_key(item, @language, @include_parameters, @fields_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
          item.to_api_deleted_list
        end
      end
      json_links = api_plain_links(contents)
      list_hash = {
        '@context' => json_context,
        '@graph' => json_contents,
        'links' => json_links
      }
      list_hash['meta'] = api_plain_meta(contents.total_count, contents.total_pages) unless @mode_parameters == 'strict'
      list_hash
    end

    def apply_classification_filters(query, filters)
      return query if filters.blank?
      classification_params = filters.to_h.deep_symbolize_keys

      classification_params.each do |operator, filter|
        filter_prefix = operator == :notIn ? 'not_' : ''
        filter&.each do |k, v|
          param_to_classifications(v).each do |classifications|
            query = query.send("#{filter_prefix}classification_alias_ids_#{k.to_s.underscore}", classifications)
          end
        end
      end
      query
    end

    def apply_geo_filters(query, filters)
      return query if filters.blank?
      geo_filter = filters.to_h.deep_symbolize_keys

      geo_filter.each do |operator, filter|
        filter_prefix = operator == :notIn ? 'not_' : ''
        filter&.each do |k, v|
          query_method = filter_prefix + query_method_mapping(k)
          next unless query.respond_to?(query_method)
          if k == :box
            query = query.send(query_method, *v)
          else
            if k == :perimeter && v.size == 3
              v = {
                'lon' => v[0],
                'lat' => v[1],
                'distance' => v[2]
              }
            end
            query = query.send(query_method, v)
          end
        end
      end
      query
    end

    def apply_attribute_filters(query, filters)
      return query if filters.blank?
      attribute_filter = filters.to_h.deep_symbolize_keys
      attribute_filter.each do |attribute_key, operator|
        attribute_path = attribute_path_mapping(attribute_key)
        query_method = query_method_mapping(attribute_key)
        operator.each do |k, v|
          query_method = 'not_' + query_method if k == :notIn
          next unless query.respond_to?(query_method)
          query = query.send(query_method, v, attribute_path)
        end
      end
      query
    end

    def apply_linked_filters(query, filters)
      return query if filters.blank?

      linked_filter = filters.to_h.deep_symbolize_keys
      linked_filter.each do |linked_name, attribute_filter|
        linked_stored_filter = DataCycleCore::StoredFilter.new
        linked_stored_filter.language = @language
        linked_query = linked_stored_filter.apply

        if attribute_filter.dig(:classifications).present?
          linked_query = apply_classification_filters(linked_query, attribute_filter.dig(:classifications))
        elsif attribute_filter.dig(:geo).present?
          linked_query = apply_geo_filters(linked_query, attribute_filter.dig(:geo))
        else
          linked_query = apply_attribute_filters(linked_query, attribute_filter.dig(:attribute))
        end

        query = query.relation_filter(linked_query, linked_name)
      end
      query
    end

    def query_method_mapping(key)
      date_range = [:modifiedAt, :createdAt]
      return 'date_range' if date_range.include?(key)
      return 'in_schedule' if key == :schedule
      return 'within_box' if key == :box
      return 'geo_radius' if key == :perimeter
      return 'geo_within_classification' if key == :shapes
      key.to_s
    end

    def attribute_path_mapping(attribute_key)
      case attribute_key
      when :modifiedAt
        'updated_at'
      when :createdAt
        'created_at'
      when :schedule
        # currently a hack
        'absolute'
      else
        attribute_key.to_s
      end
    end

    def attribute_filter_operations
      {
        in: [
          :max,
          :min,
          :equals,
          :like,
          :bool
        ],
        notIn: [
          :max,
          :min,
          :equals,
          :like,
          :bool
        ]
      }
    end

    def attribute_filters
      [
        :search,
        :q,
        {
          classifications: {
            in: {
              withSubtree: [],
              withoutSubtree: []
            },
            notIn: {
              withSubtree: [],
              withoutSubtree: []
            }
          }
        },
        {
          attribute: {
            createdAt: attribute_filter_operations,
            deletedAt: attribute_filter_operations,
            modifiedAt: attribute_filter_operations,
            schedule: attribute_filter_operations
          }
        },
        {
          geo: {
            in: {
              box: [],
              perimeter: [],
              shapes: []
            },
            notIn: {
              box: [],
              perimeter: [],
              shapes: []
            }
          }
        }
      ]
    end

    def apply_timestamp_query_string(values, attribute_path)
      date_range = "[#{date_from_single_value(values.dig(:min))&.beginning_of_day},#{date_from_single_value(values.dig(:max))&.end_of_day}]"
      ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["?::daterange @> #{attribute_path}::date", date_range])
    end

    def apply_order_query(query, order_params, full_text_search = '', schedule = false)
      order_query = []
      order_params&.split(',')&.each do |sort|
        key, order = key_with_ordering(sort)
        order_query << transform_sort_param(key, order)
      end
      order_query = order_query&.reject(&:blank?)

      if order_query.blank?
        return query.except(:order).order(DataCycleCore::Filter::Search.get_order_by_query_string(full_text_search.presence, schedule)) if schedule.present? || full_text_search.present?
        order_query = ['updated_at ASC']
      end
      query.except(:order).order(ActiveRecord::Base.send(:sanitize_sql_for_order, Arel.sql(order_query.join(', '))))
    end

    def key_with_ordering(sort)
      return sort[1..-1], 'DESC' if sort.starts_with?('-')
      return sort[1..-1], 'ASC' if sort.starts_with?('+')
      return sort, 'ASC'
    end

    private

    def date_from_single_value(value)
      return if value.blank?
      return value if value.is_a?(::Date)
      DataCycleCore::MasterData::DataConverter.string_to_datetime(value)
    end

    # TODO: add error handling
    # https://jsonapi.org/format/#errors
    def param_to_classifications(classification_string)
      classification_string.map { |classifications|
        classifications.split(',').map(&:strip).reject(&:blank?)
      }.reject(&:empty?)
    end
  end
end
