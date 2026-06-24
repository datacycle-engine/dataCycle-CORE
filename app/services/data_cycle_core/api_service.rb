# frozen_string_literal: true

module DataCycleCore
  module ApiService
    API_SCHEDULE_ATTRIBUTES = [:eventSchedule, :openingHoursSpecification, :'dc:diningHoursSpecification', :schedule, :hoursAvailable, :validitySchedule].freeze
    API_DATE_RANGE_ATTRIBUTES = [:'dct:modified', :'dct:created', :'dc:touched'].freeze
    API_SKIP_ATTRIBUTE_VALIDATION = [:graph, :linked, :attribute].freeze
    API_VALIDATE_ATTRIBUTES = [:'dct:deleted', :slug, :'skos:broader', :'skos:ancestors'].freeze
    RELATION_FILTER_TYPES = [
      *Content::Content::LINKED_PROPERTY_TYPES,
      *Content::Content::EMBEDDED_PROPERTY_TYPES
    ].freeze

    FORBIDDEN_PARENTS = {
      attribute: [:attribute]
    }.freeze

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
      return query if parameters&.dig(:content_id).blank?

      content_id = preload_content_ids(parameters[:content_id])
      search = new_thing_search(@language, content_id, true)

      return search if search.none? || query.content_ids(content_id).query.exists?

      search_first = search.first
      related_content_ids = search_first.with_cached_related_contents.where.not(id: search_first.id).pluck(:id)

      return new_thing_search(@language, nil) if related_content_ids.blank?

      if search_first.embedded?
        return new_thing_search(@language, nil) unless query.content_ids(related_content_ids).query.exists?

        search
      elsif query.content_ids(related_content_ids).query.exists?
        return new_thing_search(@language, nil) unless @linked_stored_filter.nil? || @linked_stored_filter.apply.content_ids(content_id).query.exists?

        search
      else
        new_thing_search(@language, nil)
      end
    end

    # preload single content_id if it is a slug to speed up complex queries
    def preload_content_ids(content_id)
      return content_id unless content_id.is_a?(String) && !content_id.uuid?

      DataCycleCore::Thing::Translation
        .where(slug: content_id)
        .pick(:thing_id)
    end

    def apply_filters(query, filters, key_path = [:filter])
      return query if filters.blank?

      filters.each do |filter_k, filter_v|
        if filter_k == 'union'
          query = apply_union_filters(query, filter_v)
        else
          filter_v = filter_v.to_h.deep_symbolize_keys if filter_v.respond_to?(:to_h)
          next if filter_v.blank?

          filter_method_name = "apply_#{filter_k.to_s.underscore_blanks}_filters"
          # TODO: add API error
          next unless respond_to?(filter_method_name)

          query = query_filter_method(filter_method_name, query, filter_v, key_path + [filter_k])
        end
      end

      query
    end

    def apply_classifications_filters(query, filters)
      filters.each do |operator, filter|
        filter_prefix = operator == :notIn ? 'not_' : ''
        filter&.each do |k, v|
          param_to_classifications(v).each do |classifications|
            query = query.send(:"#{filter_prefix}classification_alias_ids_#{k.to_s.underscore}", classifications)
          end
        end
      end
      query
    end

    def apply_creator_filters(query, filters)
      query_method = 'creator'
      filters.each do |operator, values|
        query_method = "not_#{query_method}" if operator == :notIn
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
      return query.schedule_search(filters.dig(:all, :in), [], include_all: true) if filters.key?(:all)

      query.in_schedule(filters&.dig(:in), 'absolute')
    end

    def apply_attribute_filters(query, filters, key_path = [:filter])
      filters.each do |attribute_key, operator|
        attribute_path = attribute_path_mapping(attribute_key)
        legacy_attribute_path = property_name_mapping(attribute_key)

        if attribute_path.nil? && legacy_attribute_path.nil?
          raise DataCycleCore::Error::Api::BadRequestError.new({
            parameter_path: parameter_path(key_path + [attribute_key]),
            type: 'invalid_parameter',
            detail: 'attribute is unknown'
          }), 'API Bad Request Error'
        end

        operator.each do |k, v|
          query_method = query_method_mapping(attribute_key, v)
          query_method = "not_#{query_method}" if k == :notIn
          next unless query.respond_to?(query_method)

          v = transform_values_for_query(v, attribute_key)

          query = if query.method(query_method)&.parameters&.size == 3
                    if attribute_path != 'absolute' && advanced_attribute_key_by_path(attribute_key).present?
                      query.send(query_method, v, advanced_attribute_type_by_path(attribute_key), attribute_path)
                    else
                      query.send(query_method, v, attribute_path, legacy_attribute_path)
                    end
                  else
                    query.send(query_method, v, attribute_path)
                  end
        end
      end

      query
    end

    def apply_linked_filters(query, linked_filter, key_path = [:filter])
      linked_filter.each do |linked_name, attribute_filter|
        linked_query = DataCycleCore::StoredFilter.new(include_embedded: true).apply_nested

        linked_query = apply_filters(linked_query, attribute_filter)
        next if linked_query.blank?

        query = query.relation_filter(
          linked_query,
          get_attribute_name_by_api_name(linked_name, key_path, RELATION_FILTER_TYPES)
        )
      end

      query
    end

    def apply_graph_filters(query, graph_filters, key_path = [:filter])
      graph_filters.each do |graph_name, attribute_filter|
        graph_query = DataCycleCore::StoredFilter.new(include_embedded: true).apply_nested

        graph_query = apply_filters(graph_query, attribute_filter)
        next if graph_query.blank?

        query = query.graph_filter(
          graph_query,
          get_attribute_name_by_api_name(graph_name, key_path, RELATION_FILTER_TYPES),
          'is_linked_to'
        )
      end

      query
    end

    def apply_union_filters(query, filters, key_path = [:filter])
      all_filters = []
      filters.each.with_index do |filter, index|
        union_query = DataCycleCore::StoredFilter.new(include_embedded: true).apply_nested

        filter.each do |filter_k, filter_v|
          filter_v = filter_v&.try(:to_h)&.deep_symbolize_keys
          next if filter_v.blank?

          filter_method_name = "apply_#{filter_k.to_s.underscore_blanks}_filters"
          next unless respond_to?(filter_method_name)

          union_query = query_filter_method(filter_method_name, union_query, filter_v, key_path + [index, filter_k])
        end

        all_filters += [union_query]
      end

      query.union_filter(all_filters)
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

    def apply_endpoint_id_filters(query, filters)
      apply_union_filter_methods(query, filters, 'union_filter_ids')
    end

    def apply_classification_tree_id_filters(query, filters)
      apply_union_filter_methods(query, filters, 'classification_tree_ids')
    end

    def apply_search_filters(query, filters)
      query.fulltext_search(filters)
    end

    alias apply_q_filters apply_search_filters

    def apply_union_filter_methods(query, filters, query_method)
      filters.each do |operator, values|
        query_method = "not_#{query_method}" if operator == :notIn
        next unless query.respond_to?(query_method)

        values.each do |v|
          query = query.send(query_method, v.split(','))
        end
      end
      query
    end

    def transform_values_for_query(value, key)
      return { 'from' => value[:min], 'until' => value[:max] } if advanced_attribute_type_by_path(key) == 'date'
      return { 'text' => value.values.first } if advanced_attribute_type_by_path(key) == 'string' && value&.values&.first.present?

      value
    end

    def query_method_mapping(key, value = nil)
      return 'date_range' if API_DATE_RANGE_ATTRIBUTES.include?(key)
      return 'in_schedule' if API_SCHEDULE_ATTRIBUTES.include?(key)
      return 'within_box' if key == :box
      return 'geo_radius' if key == :perimeter
      return 'geo_within_classification' if key == :shapes
      return 'within_shape' if key == :geoShape
      return 'equals_advanced_slug' if key == :slug
      return 'equals_advanced_attributes' if ['numeric', 'boolean'].include?(advanced_attribute_type_by_path(key))
      return "#{value.keys.first}_advanced_attributes" if advanced_attribute_key_by_path(key).present?

      key.to_s
    end

    def api_to_property_name(api_name)
      api_name.to_s.delete_prefix('dc:').delete_prefix('dcls:').underscore_blanks
    end

    def api_advanced_attribute_mapping(api_name)
      q1 = DataCycleCore::ContentProperties.where(api_name:, advanced_search: true).distinct
      q2 = DataCycleCore::ContentProperties
        .where(property_name: api_to_property_name(api_name), advanced_search: true).distinct # in case linked filters are used with actual property names (location vs content_locatin)

      q1.pluck(:property_name).presence || q2.pluck(:property_name)
    end

    def api_attribute_mapping(api_name, property_type)
      q1 = DataCycleCore::ContentProperties.where(api_name:, property_type:).distinct
      q2 = DataCycleCore::ContentProperties
        .where(property_name: api_to_property_name(api_name), property_type:).distinct # in case linked filters are used with actual property names (location vs content_locatin)

      q1.pluck(:property_name).presence || q2.pluck(:property_name)
    end

    def api_advanced_attribute_type(api_name)
      q1 = DataCycleCore::ContentProperties
        .where(api_name:, advanced_search: true).distinct
      q2 = DataCycleCore::ContentProperties
        .where(property_name: api_to_property_name(api_name), advanced_search: true)
        .distinct

      q1.pluck(:property_type).presence || q2.pluck(:property_type)
    end

    def property_name_mapping(p_name)
      property_name = api_to_property_name(p_name)
      DataCycleCore::ContentProperties.exists?(property_name:) ? property_name : nil
    end

    def advanced_attribute_type_by_path(path)
      key = advanced_attribute_key_by_path(path)
      return if key.blank?

      DataCycleCore::ApiService.additional_advanced_attributes[key]&.dig('type') ||
        api_advanced_attribute_type(key)&.first
    end

    def attribute_path_mapping(attribute_key)
      if attribute_key == :'dct:modified'
        'updated_at'
      elsif attribute_key == :'dc:touched'
        'cache_valid_since'
      elsif attribute_key == :'dct:created'
        'created_at'
      elsif attribute_key.in?(API_SCHEDULE_ATTRIBUTES)
        'absolute'
      else
        advanced_attribute_key_by_path(attribute_key)
      end
    end

    def advanced_attribute_key_by_path(path)
      key = path.to_s.underscore

      return key if DataCycleCore::ApiService.additional_advanced_attributes[key].present?

      DataCycleCore::ApiService.additional_advanced_attributes.each do |k, v|
        return k if v.is_a?(Hash) && v['path'].to_s == path.to_s
      end

      return if path.to_s.include?('_')

      api_advanced_attribute_mapping(path).first
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

    def validate_api_filters(filters, key_path = [:filter], validator = DataCycleCore::MasterData::Contracts::ApiFilterContract.new)
      raise 'API Bad Request Error' unless filters.is_a?(Hash)

      validation_errors = []

      API_SKIP_ATTRIBUTE_VALIDATION.each do |f|
        next if filters[f].blank?

        if FORBIDDEN_PARENTS.key?(f) && key_path&.intersect?(FORBIDDEN_PARENTS[f])
          raise DataCycleCore::Error::Api::BadRequestError.new(
            nested_linked_errors(filters, key_path)
          ), 'API Bad Request Error'
        end

        filters.delete(f).each do |key, filter|
          new_filter = API_VALIDATE_ATTRIBUTES.include?(key) ? { key => filter } : filter
          new_key_path = API_VALIDATE_ATTRIBUTES.include?(key) ? key_path : key_path + [f, key]

          validation_errors.concat(validate_api_filters(new_filter, new_key_path, validator))
        end
      end

      if key_path.exclude?(:union) && filters[:union].present?
        filters.delete(:union).each.with_index do |filter, index|
          validation_errors.concat(validate_api_filters(filter, key_path + [:union, index], validator))
        end
      end

      validation = validator.call(filters)
      validation_errors.concat(api_errors(validation.errors, key_path)) if validation.errors.to_h.present?
      validation_errors
    end

    def validate_api_params(unpermitted_params, exceptions = [], validate_params_contract = nil)
      validation_params = unpermitted_params&.deep_symbolize_keys&.except(*exceptions.map(&:to_sym))
      validation_errors = []

      validation_errors.concat(validate_api_filters(validation_params.delete(:filter))) if validation_params&.dig(:filter).present?

      validator = validate_params_contract&.new || DataCycleCore::MasterData::Contracts::ApiContract.new
      validation = validator.call(validation_params)
      validation_errors.concat(api_errors(validation.errors)) if validation.errors.to_h.present?

      raise DataCycleCore::Error::Api::BadRequestError.new(validation_errors), 'API Bad Request Error' if validation_errors.present?
    end

    def get_attribute_name_by_api_name(api_name, key_path, property_type)
      attribute_names = api_attribute_mapping(api_name, property_type)
      return attribute_names if attribute_names.present?

      raise DataCycleCore::Error::Api::BadRequestError.new({
        parameter_path: parameter_path(key_path + [api_name]),
        type: 'invalid_parameter',
        detail: 'attribute is unknown'
      }), 'API Bad Request Error'
    end

    # only used for classifications + deleted things endpoint
    def apply_timestamp_query_string(values, attribute_path)
      date_range = "[#{date_from_single_value(values[:min])&.beginning_of_day},#{date_from_single_value(values[:max])&.end_of_day}]"
      ActiveRecord::Base.send(:sanitize_sql_for_conditions, ["?::daterange @> #{attribute_path}::date", date_range])
    end

    def key_with_ordering(sort)
      DataCycleCore::ApiService.order_key_with_value(sort)
    end

    def self.order_value_from_params(key, raw_query_params)
      schedule_order_params = order_constraints[key]&.filter_map do |mapping|
        value = raw_query_params.dig(*mapping)
        if value.is_a?(Hash) && value.key?('all')
          value = value['all'].merge('relation' => 'all') # filter[schedule][all] => sort across all schedule relations
        elsif value.present? && value.is_a?(Hash) && mapping.last != 'schedule'
          value = value.merge('relation' => mapping.last)
        end
        value
      end

      return schedule_order_params if schedule_order_params.present? && ['proximity.occurrence_with_distance', 'proximity.in_occurrence_with_distance', 'proximity.in_occurrence_with_distance_pia'].include?(key)

      return schedule_order_params.first if schedule_order_params.present?
      return if key != 'similarity'

      search_value = raw_query_params.dig(:filter, :search) || raw_query_params.dig(:filter, :q)
      value = search_value.is_a?(Hash) ? search_value[:value] : search_value
      return if value.blank?

      search_value
    end

    def self.order_constraints
      {
        'proximity.geographic' => [['filter', 'geo', 'in', 'perimeter']],
        'proximity.inTime' => [
          ['filter', 'schedule'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ],
        'proximity.occurrence' => [
          ['filter', 'schedule'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ],
        'proximity.in_occurrence' => [
          ['filter', 'schedule'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ],
        'proximity.occurrence_with_distance' => [
          ['filter', 'geo', 'in', 'perimeter'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ],
        'proximity.in_occurrence_with_distance' => [
          ['filter', 'geo', 'in', 'perimeter'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ],
        'proximity.in_occurrence_with_distance_pia' => [
          ['filter', 'geo', 'in', 'perimeter'],
          *API_SCHEDULE_ATTRIBUTES.map { |a| ['filter', 'attribute', a.to_s] }
        ]
      }
    end

    def self.additional_advanced_attributes
      DataCycleCore::Feature::AdvancedFilter.available_advanced_attribute_filters
    end

    def self.order_key_with_value(sort)
      match_data = sort.match(/([+-]?)([\w:.@]+)(?:\(([^)]*)\))?/)

      order = match_data[1] == '-' ? 'DESC' : 'ASC'
      key = match_data[2] || sort
      order_value = match_data[3] || nil

      return key, order, order_value
    end

    def self.allowed_thread_count
      (ActiveRecord::Base.connection_pool.size / (ENV['PUMA_MAX_THREADS'] || 5)).to_i
    end

    private

    def query_filter_method(filter_method_name, query, value, key_path)
      return unless respond_to?(filter_method_name)

      if method(filter_method_name).parameters.size == 3
        send(filter_method_name, query, value, key_path)
      else
        send(filter_method_name, query, value)
      end
    end

    def parameter_path(key_path)
      key_path.drop(1).inject(key_path.first.to_s) { |a, b| a << "[#{b}]" }
    end

    def new_thing_search(language, ids, embedded = false)
      DataCycleCore::Filter::Search
        .new(
          locale: language,
          query: ids.blank? ? DataCycleCore::Thing.none : DataCycleCore::Thing.limit(1),
          include_embedded: embedded
        )
        .content_ids(ids)
    end

    def api_errors(errors, key_path = [])
      errors.map do |error|
        error_path = error.path.is_a?(::String) ? error.path.split('.') : error.path
        error_path.prepend(*key_path) if key_path.present?

        {
          parameter_path: parameter_path(error_path),
          type: error.path.is_a?(::String) ? 'unknown_parameter' : 'invalid_parameter',
          detail: error.to_s
        }
      end
    end

    def nested_linked_errors(filter, key_path)
      param_path = parameter_path(key_path)

      while filter.is_a?(Hash) && filter.any?
        key = filter.keys.first
        param_path << "[#{key}]"
        filter = filter[key]
      end

      [{
        parameter_path: param_path,
        type: 'invalid_parameter',
        detail: 'is not allowed'
      }]
    end

    def date_from_single_value(value)
      return if value.blank?
      return value if value.is_a?(::Date)

      DataCycleCore::MasterData::DataConverter.string_to_datetime(value)
    end

    # @todo: error handling
    # https://jsonapi.org/format/#errors
    def param_to_classifications(classification_string)
      classification_string.map { |classifications|
        classifications.split(',').map(&:strip).compact_blank
      }.reject(&:empty?)
    end
  end
end
