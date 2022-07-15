# frozen_string_literal: true

module DataCycleCore
  module ApiService
    API_SCHEDULE_ATTRIBUTES = [:eventSchedule, :openingHoursSpecification, :'dc:diningHoursSpecification', :schedule, :hoursAvailable, :validitySchedule].freeze
    API_DATE_RANGE_ATTRIBUTES = [:'dct:modified', :'dct:created'].freeze
    API_NUMERIC_ATTRIBUTES = [:width, :height, :numberOfRooms, :numberOfAccommodations, :numberOfMeetingRooms, :maxNumberOfPeople, :totalNumberOfBeds].freeze

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
      list_hash['meta'] = api_plain_meta(contents.total_count, contents.total_pages) unless @permitted_params.dig(:section, :meta)&.to_i&.zero?
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
      list_hash['meta'] = api_plain_meta(contents.total_count, contents.total_pages) unless @permitted_params.dig(:section, :meta)&.to_i&.zero?
      list_hash
    end

    def append_filters(query, parameters)
      query = query.content_ids(parameters[:content_id]) if parameters&.dig(:content_id).present?
      query
    end

    def apply_filters(query, filters)
      return query if filters.blank?
      filters.each do |filter_k, filter_v|
        if filter_k == 'union'
          query = apply_union_filters(query, filter_v)
        else
          filter_v = filter_v&.try(:to_h)&.deep_symbolize_keys
          next if filter_v.blank?
          filter_method_name = "apply_#{filter_k.to_s.underscore_blanks}_filters"
          # TODO: add API error
          next unless respond_to?(filter_method_name)
          query = send(filter_method_name, query, filter_v)
        end
      end
      query
    end

    def apply_classifications_filters(query, filters)
      filters.each do |operator, filter|
        filter_prefix = operator == :notIn ? 'not_' : ''
        filter&.each do |k, v|
          param_to_classifications(v).each do |classifications|
            query = query.send("#{filter_prefix}classification_alias_ids_#{k.to_s.underscore}", classifications)
          end
        end
      end
      query
    end

    def apply_creator_filters(query, filters)
      query_method = 'creator'
      filters.each do |operator, values|
        query_method = 'not_' + query_method if operator == :notIn
        next unless query.respond_to?(query_method)
        values.each do |v|
          query = query.send(query_method, v.split(','))
        end
      end
      query
    end

    alias apply_dc_classification_filters apply_classifications_filters

    def apply_geo_filters(query, filters)
      filters.each do |operator, filter|
        if operator == :withGeometry
          filter_prefix = filter.to_s == 'true' ? '' : 'not_'
          query_method = filter_prefix + operator.to_s.underscore
          query = query.send(query_method)
        else
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
      end
      query
    end

    def apply_schedule_filters(query, filters)
      query.in_schedule(filters&.dig(:in), 'absolute')
    end

    def apply_attribute_filters(query, filters)
      filters.each do |attribute_key, operator|
        attribute_path = attribute_path_mapping(attribute_key)
        query_method = query_method_mapping(attribute_key)
        operator.each do |k, v|
          query_method = 'not_' + query_method if k == :notIn
          next unless query.respond_to?(query_method)

          if query.method(query_method)&.parameters&.size == 3
            query = query.send(query_method, v, attribute_path, attribute_key.to_s.delete_prefix('dc:').underscore_blanks)
          else
            query = query.send(query_method, v, attribute_path)
          end
        end
      end
      query
    end

    def apply_linked_filters(query, linked_filter)
      linked_filter.each do |linked_name, attribute_filter|
        linked_query = DataCycleCore::StoredFilter.new(language: @language).apply

        # add error handling for invalid methods
        attribute_filter.delete_if { |k, _v| ![:classifications, :'dc:classification', :geo, :attribute, :contentId, :filterId, :watchListId].include?(k) }

        linked_query = apply_filters(linked_query, attribute_filter)
        query = query.relation_filter(linked_query, linked_attribute_mapping(linked_name)) if linked_query.present?
      end
      query
    end

    def apply_union_filters(query, filters)
      all_filters = []
      filters.each do |filter|
        union_query = DataCycleCore::StoredFilter.new(language: @language).apply

        filter.each do |filter_k, filter_v|
          filter_v = filter_v&.try(:to_h)&.deep_symbolize_keys
          next if filter_v.blank?
          filter_method_name = ('apply_' + filter_k.to_s.underscore.parameterize(separator: '_') + '_filters')
          # TODO: add API error
          next unless respond_to?(filter_method_name)
          union_query = send(filter_method_name, union_query, filter_v)
        end
        all_filters += [union_query]
      end
      query = query.union_filter(all_filters)
      query
    end

    def apply_content_id_filters(query, filters)
      apply_union_filter_methods(query, filters, 'content_ids')
    end

    def apply_filter_id_filters(query, filters)
      apply_union_filter_methods(query, filters, 'filter_ids')
    end

    def apply_watch_list_id_filters(query, filters)
      apply_union_filter_methods(query, filters, 'watch_list_ids')
    end

    def apply_union_filter_methods(query, filters, query_method)
      filters.each do |operator, values|
        query_method = 'not_' + query_method if operator == :notIn
        next unless query.respond_to?(query_method)
        values.each do |v|
          query = query.send(query_method, v.split(','))
        end
      end
      query
    end

    def query_method_mapping(key)
      return 'date_range' if API_DATE_RANGE_ATTRIBUTES.include?(key)
      return 'equals_advanced_numeric' if API_NUMERIC_ATTRIBUTES.include?(key)
      return 'in_schedule' if API_SCHEDULE_ATTRIBUTES.include?(key)
      return 'within_box' if key == :box
      return 'geo_radius' if key == :perimeter
      return 'geo_within_classification' if key == :shapes
      return 'equals_advanced_slug' if key == :slug
      key.to_s
    end

    def linked_attribute_mapping(linked_name)
      case linked_name
      when :location
        'content_location'
      else
        linked_name&.to_s&.underscore
      end
    end

    def attribute_path_mapping(attribute_key)
      if attribute_key == :'dct:modified'
        'updated_at'
      elsif attribute_key == :'dct:created'
        'created_at'
      elsif attribute_key.in?(API_SCHEDULE_ATTRIBUTES)
        'absolute'
      else
        attribute_key.to_s.underscore
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

    def classification_filter_operations
      {
        in: {
          withSubtree: [],
          withoutSubtree: []
        },
        notIn: {
          withSubtree: [],
          withoutSubtree: []
        }
      }
    end

    def attribute_filters
      [
        :search,
        :q,
        {
          classifications: classification_filter_operations
        },
        {
          'dc:classification': classification_filter_operations
        },
        {
          attribute: {
            'dct:created': attribute_filter_operations,
            'dct:deleted': attribute_filter_operations,
            'dct:modified': attribute_filter_operations,
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

    def validate_api_params(unpermitted_params)
      validator = DataCycleCore::MasterData::Contracts::ApiContract.new
      linked_validator = DataCycleCore::MasterData::Contracts::ApiLinkedContract.new

      validation_params = unpermitted_params&.deep_symbolize_keys&.except(:'dc:liveData')
      linked_params = validation_params[:filter].delete(:linked) if validation_params.dig(:filter, :linked).present?
      union_params = validation_params[:filter].delete(:union) if validation_params.dig(:filter, :union).present?

      validation = validator.call(validation_params)
      validation_errors = validation.errors.to_h.present? ? api_errors(validation.errors) : []
      linked_params&.each do |linked_name, attribute_filter|
        linked_validation = linked_validator.call(attribute_filter)
        validation_errors += api_errors(linked_validation.errors, linked_name) if linked_validation.errors.to_h.present?
      end
      union_params&.each do |union_parameters|
        union_validation_errors = validate_api_union_params(union_parameters)
        validation_errors += union_validation_errors if union_validation_errors.present?
      end

      raise DataCycleCore::Error::Api::BadRequestError.new(validation_errors), 'API Bad Request Error' if validation_errors.present?
    end

    def validate_api_union_params(unpermitted_params)
      validator = DataCycleCore::MasterData::Contracts::ApiUnionFilterContract.new
      linked_validator = DataCycleCore::MasterData::Contracts::ApiLinkedContract.new

      # TODO: add validation and correct API error message
      raise 'API Bad Request Error' unless unpermitted_params.is_a?(Hash)

      validation_params = unpermitted_params&.deep_symbolize_keys
      linked_params = validation_params.delete(:linked) if validation_params.dig(:linked).present?

      validation = validator.call(validation_params)
      validation_errors = validation.errors.to_h.present? ? api_errors(validation.errors) : []
      linked_params&.each do |linked_name, attribute_filter|
        linked_validation = linked_validator.call(attribute_filter)
        validation_errors += api_errors(linked_validation.errors, linked_name) if linked_validation.errors.to_h.present?
      end
      validation_errors
    end

    # only used for classifications + deleted things endpoint
    def apply_timestamp_query_string(values, attribute_path)
      date_range = "[#{date_from_single_value(values.dig(:min))&.beginning_of_day},#{date_from_single_value(values.dig(:max))&.end_of_day}]"
      ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["?::daterange @> #{attribute_path}::date", date_range])
    end

    def order_params_present?(params)
      [
        params[:sort]&.split(',').present?,
        params.dig(:filter, :search).present?,
        params.dig(:filter, :q).present?,
        order_value_from_params('proximity.geographic', '', params.to_h).present?,
        order_value_from_params('proximity.inTime', '', params.to_h).present?
      ].any?
    end

    def apply_order_query(query, order_params, full_text_search = '', raw_query_params: {})
      order_query = []
      order_params&.split(',')&.each do |sort|
        key, order = key_with_ordering(sort)
        value = order_value_from_params(key, full_text_search, raw_query_params)
        order_hash = {
          'm' => key.parameterize(separator: '_'),
          'o' => order
        }
        order_hash['v'] = value if value.present?
        order_query << order_hash
      end
      order_query = order_query&.reject(&:blank?)

      if order_query.blank?
        # default order depending on filter parameter
        query = query.sort_fulltext_search('DESC', full_text_search) if full_text_search.present?
        query = query.sort_proximity_geographic('ASC', order_value_from_params('proximity.geographic', full_text_search, raw_query_params)) if order_value_from_params('proximity.geographic', full_text_search, raw_query_params)
        query = query.sort_by_proximity('', order_value_from_params('proximity.inTime', full_text_search, raw_query_params)) if order_value_from_params('proximity.inTime', full_text_search, raw_query_params).present?
        return query
      end

      query = query.reset_sort
      order_query.each do |sort|
        sort_method_name = 'sort_' + sort['m']
        next unless query.respond_to?('sort_' + sort['m'])

        if query.method(sort_method_name)&.parameters&.size == 2
          query = query.send(sort_method_name, sort['o'].presence, sort['v'].presence)
        elsif query.method(sort_method_name)&.parameters&.size == 1
          query = query.send(sort_method_name, sort['o'].presence)
        else
          next
        end
      end

      query
    end

    def order_value_from_params(key, full_text_search, raw_query_params)
      schedule_order_params = order_constraints.dig(key)&.map { |c| raw_query_params.dig(*c) }&.compact
      return schedule_order_params.first if schedule_order_params.present?
      return full_text_search if key == 'similarity' && full_text_search.present?
    end

    def key_with_ordering(sort)
      DataCycleCore::ApiService.order_key_with_value(sort)
    end

    def order_constraints
      {
        'proximity.geographic' => [['filter', 'geo', 'in', 'perimeter']],
        'proximity.inTime' => [
          ['filter', 'schedule'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ],
        'proximity.occurrence' => [
          ['filter', 'schedule'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ]
      }
    end

    def self.order_key_with_value(sort)
      return sort[1..-1], 'DESC' if sort.starts_with?('-')
      return sort[1..-1], 'ASC' if sort.starts_with?('+')
      return 'random', sort.match(/random\((.+)\)/i)&.captures&.first&.to_f if sort.starts_with?('random')
      return sort, 'ASC'
    end

    private

    def api_errors(errors, linked_name = nil)
      errors.map do |error|
        type = 'invalid_parameter'
        error_path = error.path
        if error.path.is_a?(::String)
          type = 'unknown_parameter'
          error_path = error.path.split('.')
        end
        error_path.prepend(:filter, :linked, linked_name) if linked_name.present?
        parameter_path = error_path.drop(1).inject(error_path.first.to_s) { |a, b| a << "[#{b}]" }
        {
          parameter_path: parameter_path,
          type: type,
          detail: error.to_s
        }
      end
    end

    # TODO: check if required
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
