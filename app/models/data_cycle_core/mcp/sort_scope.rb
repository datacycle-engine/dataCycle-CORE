# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Resolves the sort parameter of search_contents onto one of the Filter::Sortable scopes.
    #
    # Without that parameter a "top N" question cannot be answered, but it LOOKS answerable:
    # base_query carries sort_default (boost/updated_at/id), limit cuts the first page off it, and a
    # client asking for "the 5 longest tours" gets five arbitrary tours -- with no error and without
    # the length in the result that the order could be checked against. That is why #value_for ships
    # the sorted value per hit.
    #
    # Only ONE sort criterion: each Sortable scope rebuilds the order through query_without_order, so
    # a second call discards the first. An array of criteria would promise a multi-column sort the
    # query layer cannot do -- the REST side resolves it the same way (apply_order_parameters! takes
    # the first effective criterion).
    class SortScope
      include DataCycleCore::ApiService
      include DataCycleCore::Mcp::BadRequest

      # Sort keys that are not an advanced_search attribute, with their scope and default direction.
      # distance needs near in the same call -- the sort uses that same point.
      BUILT_INS = {
        'dct:created' => { method: :sort_created_at, direction: 'desc' },
        'dct:modified' => { method: :sort_updated_at, direction: 'desc' },
        'name' => { method: :sort_translated_name, direction: 'asc' },
        'distance' => { method: :sort_proximity_geographic, direction: 'asc' }
      }.freeze

      # Numeric attributes only: their values sit in searches.advanced_attributes as JSON numbers
      # and can be reduced to a scalar reliably (see
      # Filter::Sortable#sort_advanced_attribute_numeric). date/date_range/string/boolean are
      # deliberately left out -- a sort that is only sometimes right is worse than an error.
      SORTABLE_TYPES = ['number', 'numeric'].freeze

      DIRECTIONS = ['asc', 'desc'].freeze

      class << self
        # The input_schema fragment for search_contents -- here, so the sort semantics sit in one
        # place and the tool stays restricted to applying the filters.
        #
        # Its own locale namespace (mcp.sort.*) rather than mcp.tools.search_contents.arguments.*:
        # the semantics belong to this class, and it should not reach into the namespace of a tool
        # that merely includes it -- as with the shared mcp.scope.global.
        def parameter_schema(locale: I18n.default_locale)
          {
            type: 'object',
            description: t('parameter', locale),
            properties: {
              attribute: { type: 'string', description: t('attribute', locale) },
              direction: { type: 'string', enum: DIRECTIONS, description: t('direction', locale) }
            },
            required: ['attribute'],
            additionalProperties: false
          }
        end

        # nil when no sort was passed -- the caller then stays on sort_default.
        def build(arguments, template_names:)
          return if arguments[:sort].blank?

          new(arguments[:sort], template_names:, near: arguments[:near])
        end

        private

        def t(key, locale)
          DataCycleCore::Mcp::Translations.t("sort.#{key}", locale:)
        end
      end

      def initialize(sort, template_names:, near: nil)
        sort = sort.to_h.deep_symbolize_keys
        @attribute = sort[:attribute].to_s
        @requested_direction = sort[:direction].presence&.to_s&.downcase
        @template_names = template_names
        # near is normalised just like sort above, and for the same reason: with string keys
        # #geo_value would otherwise return [nil, nil], and
        # Filter::Sortable::Proximity#sort_proximity_geographic discards invalid coordinates
        # SILENTLY -- the response would be an unsorted list presenting itself as a distance ranking
        # through applied_filters.sort. Tools::Base now normalises the arguments at the entrance
        # already; it stays here because this class is also constructed directly and must then hold
        # its promise on its own.
        @near = near.presence&.to_h&.with_indifferent_access
      end

      # Replaces the order of the given Filter::Search. Raises on an unknown or non-sortable key
      # instead of silently falling back to sort_default: the client would otherwise report the
      # unordered first page as a ranking.
      def apply(query)
        validate!

        built_in = BUILT_INS[@attribute]
        return query.public_send(built_in[:method], direction, geo_value) if built_in && @attribute == 'distance'
        return query.public_send(built_in[:method], direction) if built_in

        query.sort_advanced_attribute_numeric(direction, attribute_path)
      end

      # The sorted value of the hit -- so the order is verifiable from the result and does not have
      # to be guessed from the title ("Montafon Totale Ultra: length 47 kilometres"). For the
      # BUILT_INS the value is already in the summary (created_at/updated_at/title) or follows from
      # near (distance).
      def value_for(thing)
        return {} if BUILT_INS.key?(@attribute)

        property = attribute_path
        return {} unless thing.property_names.include?(property)

        { sort_value: thing.try(property), sort_unit: unit }.compact
      end

      # The resolved criterion for applied_filters -- including the unit, because a ranking without
      # it ("the longest: 9978000") is not readable.
      def to_h
        { attribute: @attribute, direction:, unit: }.compact
      end

      private

      def direction
        @direction ||= @requested_direction.presence || default_direction
      end

      def default_direction
        BUILT_INS.dig(@attribute, :direction) || 'desc'
      end

      # [lon, lat] as Filter::Sortable::Proximity#sort_proximity_geographic expects it.
      def geo_value
        [@near[:lon], @near[:lat]]
      end

      # The key walk_advanced stores the value under in searches.advanced_attributes -- that is the
      # internal property_name ("length"), not the api_name ("odta:length").
      def attribute_path
        @attribute_path ||= advanced_attribute_key_by_path(@attribute)
      end

      def sortable_attribute
        return @sortable_attribute if defined?(@sortable_attribute)

        @sortable_attribute = DataCycleCore::Mcp::AttributeFilter.new
          .available(@template_names)
          .find { |a| a[:attribute].to_s == @attribute && a[:type].to_s.in?(SORTABLE_TYPES) }
      end

      def unit
        sortable_attribute&.dig(:unit)
      end

      def validate!
        bad_request!('sort.direction', "must be one of #{DIRECTIONS.join(', ')}") if @requested_direction.present? && !@requested_direction.in?(DIRECTIONS)
        bad_request!('sort.attribute', 'must not be blank') if @attribute.blank?

        bad_request!('sort.attribute', 'sorting by "distance" requires the near filter (lat/lon/radius_km) in the same call') if @attribute == 'distance' && @near.blank?

        return if BUILT_INS.key?(@attribute) || (sortable_attribute.present? && attribute_path.present?)

        bad_request!('sort.attribute', "'#{@attribute}' is not sortable. Sortable keys: #{sortable_keys.join(', ')}")
      end

      # The complete list on failure: without it a client keeps trying variants of the same key or
      # falls back to query.
      def sortable_keys
        BUILT_INS.keys + DataCycleCore::Mcp::AttributeFilter.new
          .available(@template_names)
          .select { |a| a[:type].to_s.in?(SORTABLE_TYPES) }
          .pluck(:attribute)
      end
    end
  end
end
