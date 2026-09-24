# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # Full-text, facet, date-range and geo search over the endpoint scoped by base_query --
      # combines the filters of the individual query scopes into one tool call.
      class SearchContents < Base
        self.tool_name = 'search_contents'
        # query/classification_alias_ids/schedule/limit have no 1:1 OpenAPI counterpart: the OpenAPI
        # operation getEndpointContents bundles them only inside the deepObject parameter `filter`
        # (the Filter/ScheduleFilter schema, with a different nesting). The flat shape here is a
        # deliberate deviation: the nesting makes sense for REST, not for an LLM tool schema.
        input_schema do |locale|
          {
            type: 'object',
            properties: {
              query: { type: 'string', description: argument_description('query', locale:) },
              template_names: {
                type: 'array', items: { type: 'string' },
                description: argument_description('template_names', locale:)
              },
              classification_alias_ids: {
                type: 'array', items: { type: 'string', format: 'uuid' },
                description: argument_description('classification_alias_ids', locale:)
              },
              classification_alias_id_groups: {
                type: 'array', items: { type: 'array', items: { type: 'string', format: 'uuid' } },
                description: argument_description('classification_alias_id_groups', locale:)
              },
              exclude_classification_alias_ids: {
                type: 'array', items: { type: 'string', format: 'uuid' },
                description: argument_description('exclude_classification_alias_ids', locale:)
              },
              include_subtree: { type: 'boolean', description: argument_description('include_subtree', locale:) },
              # Deliberately without properties/additionalProperties: the date-range filter is passed
              # through unchanged to Filter::Common::Schedule#in_schedule, whose shape (absolute vs.
              # relative, nested n/unit/mode) should not be declared a second time here. Set
              # strictly, additionalProperties forbids EVERY key when properties is absent.
              schedule: { type: 'object', description: argument_description('schedule', locale:) },
              place: { type: 'string', description: argument_description('place', locale:) },
              near: {
                type: 'object',
                description: argument_description('near', locale:),
                properties: {
                  lat: { type: 'number' },
                  lon: { type: 'number' },
                  radius_km: { type: 'number' }
                },
                required: ['lat', 'lon', 'radius_km'],
                additionalProperties: false
              },
              attributes: {
                type: 'array',
                description: argument_description('attributes', locale:),
                items: {
                  type: 'object',
                  properties: {
                    attribute: { type: 'string', description: argument_description('attribute_condition.attribute', locale:) },
                    # minProperties: 1 -- "in": {} filters nothing. Without that boundary the
                    # endpoint's total would come back while applied_filters names the attribute
                    # (see Mcp::AttributeFilter#build_filters, which rejects the same case server-side).
                    in: condition_schema(argument_description('attribute_condition.in', locale:)),
                    not_in: condition_schema(argument_description('attribute_condition.not_in', locale:))
                  },
                  required: ['attribute'],
                  additionalProperties: false
                }
              },
              has_relations: {
                type: 'array', items: { type: 'string' },
                description: argument_description('has_relations', locale:)
              },
              missing_relations: {
                type: 'array', items: { type: 'string' },
                description: argument_description('missing_relations', locale:)
              },
              # The sort semantics live in Mcp::SortScope, not here -- including the rule about which
              # keys are sortable at all.
              sort: DataCycleCore::Mcp::SortScope.parameter_schema(locale:),
              limit: { type: 'integer', minimum: 1, default: 20, description: argument_description('limit', locale:) },
              explain: { type: 'boolean', description: argument_description('explain', locale:) }
            }
          }
        end

        # in and not_in have the same shape and differ only in their description -- written out
        # twice, the operator lists of the two drifted apart.
        def self.condition_schema(description)
          {
            type: 'object',
            description:,
            properties: {
              min: { type: ['number', 'string'] },
              max: { type: ['number', 'string'] },
              equals: { type: ['number', 'string'] },
              like: { type: 'string' },
              bool: { type: 'boolean' }
            },
            minProperties: 1,
            additionalProperties: false
          }
        end

        # Applies the given filters to context[:base_query] in order and paginates.
        def call(arguments:, context:)
          explain = DataCycleCore::Mcp::FilterExplain.new(enabled: arguments[:explain] == true)
          groups = positive_groups(arguments)
          place_scope = arguments[:place].present? ? DataCycleCore::Mcp::GeoScope.resolve(arguments[:place]) : nil

          search = apply_filters(context[:base_query], arguments, explain, groups:, place_scope:)

          # LAST: the Sortable scopes rebuild the order through query_without_order (discarding the
          # relevance ordering of a text search along the way) -- applied before a filter, it would
          # be overwritten again by that filter's scope.
          sort_scope = DataCycleCore::Mcp::SortScope.build(arguments, template_names: scope_template_names(context))
          search = sort_scope.apply(search) if sort_scope.present?

          limit = limit_from(arguments)
          # count BEFORE the pagination: the real total hit count (not capped by limit), so that
          # "count me ..." requests are reliable. items is the first page of it.
          total = search.count
          things = search.page(1).per(limit).to_a

          description = filter_description(arguments, groups, context:, place_scope:, search:, explain:, sort_scope:)
          add_warning(unresolved_concepts_warning(description.unresolved_ids), unresolved_place_warning(description.unresolved_place))

          {
            count: total,
            returned: things.size,
            items: things.map { |thing| summarize_thing(thing).merge(sort_scope&.value_for(thing) || {}) },
            applied_filters: description.to_h(explain_steps: explain.steps)
          }
        end

        private

        # A passed id without a concept filters NOTHING, so count is the UNFILTERED set -- reported
        # as an answer that is a plausible and much too high number. applied_filters names the group
        # each id sits in; this is what reaches a client that reads only the envelope.
        def unresolved_concepts_warning(ids)
          return if ids.blank?

          DataCycleCore::Mcp::Translations.t('warnings.unresolved_concept_ids', ids: ids.join(', '))
        end

        # An unresolvable place name yields no filter step, so count is the UNFILTERED set -- the same
        # trap as an unresolved concept id above. applied_filters.place.resolved states it too, nested
        # where a client that reads only the envelope does not look.
        def unresolved_place_warning(place)
          return if place.blank?

          DataCycleCore::Mcp::Translations.t('warnings.unresolved_place', place:)
        end

        # Folds Mcp::FilterSteps' step list over the starting set and records after every step. Which
        # filters exist and in what order they take effect is stated there -- a filter that was not
        # requested yields no step, hence no conditions left here.
        def apply_filters(search, arguments, explain, groups:, place_scope:)
          explain.record('endpoint', search)

          steps = DataCycleCore::Mcp::FilterSteps.new(arguments:, groups:, place_scope:).to_a

          steps.reduce(search) do |current, (label, detail, apply)|
            apply.call(current).tap { |applied| explain.record(label, applied, detail:) }
          end
        end

        # The description of the resolved filter lives in Mcp::FilterDescription -- this tool stays
        # restricted to applying the filters.
        def filter_description(arguments, groups, context:, place_scope:, search:, explain:, sort_scope: nil)
          DataCycleCore::Mcp::FilterDescription.new(
            arguments:,
            groups:,
            # The same source the application picks its scope from -- otherwise the response could
            # report a different subtree mode than the one filtered on.
            include_subtree: DataCycleCore::Mcp::FilterSteps.include_subtree?(arguments),
            units: attribute_units(arguments, context),
            place_scope:,
            place_coverage: place_coverage(place_scope, search, explain),
            sort: sort_scope&.to_h
          )
        end

        # Coupled to the same switch as the step log: coverage costs its own COUNT over the filtered
        # set per cascade stage (so three extra aggregates per search at three stages). Both are
        # diagnostics for putting a number in context, and neither should make every search more
        # expensive -- computing it unconditionally would be exactly the inconsistency explain exists
        # to avoid. resolve_place still returns coverage unconditionally: there the coverage IS the
        # result, not an additional detail.
        def place_coverage(place_scope, search, explain)
          return unless explain.enabled?

          place_scope&.coverage(search)
        end

        # The same section as list_attributes: a unit from a template the endpoint does not contain
        # would be misleading. Looked up only when attribute filters are set.
        def attribute_units(arguments, context)
          return {} if arguments[:attributes].blank?

          DataCycleCore::Mcp::AttributeFilter.new
            .available(scope_template_names(context))
            .to_h { |a| [a[:attribute].to_s, a[:unit]] }
            .compact
        end

        # The AND-combined positive facet groups; classification_alias_ids is the shorthand for a
        # single group.
        def positive_groups(arguments)
          groups = Array.wrap(arguments[:classification_alias_id_groups]).map { |ids| Array.wrap(ids) }
          groups.unshift(Array.wrap(arguments[:classification_alias_ids]))
          groups.compact_blank
        end
      end
    end
  end
end
