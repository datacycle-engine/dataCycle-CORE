# frozen_string_literal: true

module DataCycleCore
  module ApiService
    def list_api_request(contents = nil)
      contents ||= @contents
      json_context = api_plain_context(@language)
      json_contents = contents.map do |item|
        Rails.cache.fetch("api_v4_#{api_cache_key(item, @language, @include_parameters, @fields_parameters, @api_subversion)}", expires_in: 1.year + Random.rand(7.days)) do
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
        Rails.cache.fetch("api_v4_#{api_cache_key(item, @language, @include_parameters, @fields_parameters, @api_subversion)}", expires_in: 1.year + Random.rand(7.days)) do
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

    def apply_classification_filters(query)
      return query if permitted_params&.dig(:filter, :classifications).blank?
      classification_params = permitted_params[:filter][:classifications].to_h.deep_symbolize_keys

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

    def apply_geo_filters(query)
      return query if permitted_params&.dig(:filter, :geo).blank?
      geo_filter = permitted_params[:filter][:geo].to_h.deep_symbolize_keys

      geo_filter.each do |operator, filter|
        filter_prefix = operator == :notIn ? 'not_' : ''
        filter&.each do |k, v|
          query_method = filter_prefix + query_method_mapping(k)
          next unless query.respond_to?(query_method)
          query = query.send(query_method, *v)
        end
      end
      query
    end

    def apply_attribute_filters(query)
      return query if permitted_params&.dig(:filter, :attribute).blank?
      attribute_filter = permitted_params[:filter][:attribute].to_h.deep_symbolize_keys
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

    def query_method_mapping(key)
      date_range = [:modifiedAt, :createdAt]
      return 'date_range' if date_range.include?(key)
      return 'in_schedule' if key == :schedule
      return 'within_box' if key == :box
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

    def apply_timestamp_query_string(values, attribute_path)
      date_range = "[#{date_from_single_value(values.dig(:min))&.beginning_of_day},#{date_from_single_value(values.dig(:max))&.end_of_day}]"
      ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["?::daterange @> #{attribute_path}::date", date_range])
    end

    def apply_order_query(query, order_params)
      order_query = []
      order_params&.split(',')&.each do |sort|
        key, order = key_with_ordering(sort)
        order_query << transform_sort_param(key, order)
      end

      order_query = order_query&.reject(&:blank?)
      order_query = ['updated_at ASC'] if order_query.blank?
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
