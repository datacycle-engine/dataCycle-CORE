# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V4
      module Mcp
        # Functional tests for the SingleEndpointServer tools: proves that tools/call returns
        # correct data derived from real content/classifications, not just a 200 -- complements
        # mcp_authorization_test.rb, which only proves the access boundary.
        class McpToolsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::McpTestHelper
          include DataCycleCore::I18nTestHelper

          before(:all) do
            DataCycleCore::Thing.delete_all

            @creator = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
            @creator.update!(access_token: SecureRandom.hex) if @creator.access_token.blank?

            @concept_scheme = DataCycleCore::ConceptScheme.find_by(name: 'Tags')
            @concept = @concept_scheme.concepts.first

            @content1 = create_content('Artikel', { name: 'MCP Test Alpha', tags: [@concept.id] }, @creator)
            @content2 = create_content('Artikel', { name: 'MCP Test Beta' }, @creator)

            @endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp tools test',
              user_id: @creator.id,
              api: true,
              concept_scheme_ids: [@concept_scheme.id],
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel'] }]
            )
          end

          test 'search_contents finds real content by query' do
            result = call_tool('search_contents', { 'query' => 'Alpha' })

            assert_equal 1, result['count']
            assert_equal @content1.id, result.dig('items', 0, 'id')
          end

          test 'get_content returns the full content for a known id' do
            result = call_tool('get_content', { 'id' => @content1.id })

            assert_equal @content1.id, result['id']
          end

          test 'get_content with an unknown id returns a mapped errors[] payload, not a generic internal error' do
            body = call_tool_raw('get_content', { 'id' => SecureRandom.uuid })

            assert body.dig('result', 'isError')
            assert_predicate body.dig('result', 'structuredContent', 'errors', 0, 'title'), :present?
          end

          test 'list_facets lists the concept scheme linked to the endpoint' do
            result = call_tool('list_facets', {})

            assert_includes result['schemes'].pluck('id'), @concept_scheme.id
          end

          test 'list_facets derives facets from the result set when no concept scheme is configured' do
            # An endpoint without curated concept_schemes: list_facets has to derive the trees that
            # actually occur in the results (rather than an empty list), so facet_values is usable
            # afterwards. @content1 carries @concept from @concept_scheme.
            unconfigured_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp tools test unconfigured',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel'] }]
            )

            result = call_tool('list_facets', {}, endpoint_id: unconfigured_endpoint.id)

            assert_includes result['schemes'].pluck('id'), @concept_scheme.id
          end

          test 'list_facets and facet_values deliver the curated tree definition, and omit the field for undocumented trees' do
            # The tree name alone does not tell a client which dimension it represents -- the
            # definition from config/locales/{de,en}.mcp.yml is the only channel for that. Both are
            # tested: that it arrives, and that a tree WITHOUT a definition omits the field (rather
            # than carrying it empty), because only that keeps "not documented" distinguishable from
            # "empty". 'Tags' is deliberately not in the locale files; the definition is stubbed.
            undocumented = call_tool('list_facets', {})['schemes'].detect { |s| s['id'] == @concept_scheme.id }

            assert_not undocumented.key?('description'), 'an undocumented tree must not carry a description field'
            assert_not call_tool('facet_values', { 'classification_tree_label_id' => @concept_scheme.id }).key?('description')

            definition = 'Freie Verschlagwortung, flache Liste -- keine Sachkategorie.'

            # store_translations writes into the process's backend cache and would otherwise bleed
            # into every following test of this worker. Cleanup goes through the exact initial state
            # and NOT through I18n.reload! -- why is stated in I18nTestHelper.
            with_stored_translations({ mcp: { concept_schemes: { @concept_scheme.name.to_sym => { description: definition } } } }) do
              documented = call_tool('list_facets', {})['schemes'].detect { |s| s['id'] == @concept_scheme.id }

              assert_equal definition, documented['description']
              assert_equal definition, call_tool('facet_values', { 'classification_tree_label_id' => @concept_scheme.id })['description']
            end
          end

          test 'list_facets and facet_values report the measured tree metrics instead of prose' do
            # The metrics replace the numbers that until then were written into the curated
            # definition as prose and went stale with every import (see Mcp::ConceptSchemeMetrics).
            # What is tested above all is the SEPARATION of the two measurements: concept_count is
            # structure and therefore instance-wide, thing_count is the occupancy IN the endpoint.
            # Were both to come from the same scope, "the tree has N concepts" would no longer be
            # distinguishable from "N categories are occupied in the endpoint" -- and precisely that
            # confusion produces the plausible but wrong number.
            scheme = call_tool('list_facets', {})['schemes'].detect { |s| s['id'] == @concept_scheme.id }

            assert_equal @concept_scheme.concepts.count, scheme['concept_count']
            assert_equal 1, scheme['thing_count'], 'only @content1 carries @concept, @content2 does not'
            assert_operator scheme['depth'], :>=, 1

            values = call_tool('facet_values', { 'classification_tree_label_id' => @concept_scheme.id })

            assert_equal @concept_scheme.name, values['name']
            assert_equal scheme['concept_count'], values['concept_count']
            assert_equal scheme['thing_count'], values['thing_count']
            # Beside the values list the tree id would read as the id of a value, and the caller has
            # just passed it itself.
            assert_not values.key?('id')
          end

          test 'facet_values returns the real content count for the tagged alias' do
            result = call_tool('facet_values', { 'classification_tree_label_id' => @concept_scheme.id })

            entry = result['values'].find { |v| v['id'] == @concept.id }

            assert_equal 1, entry['thing_count_with_subtree']
          end

          test 'facet_values hides empty concepts by default and includes them at min_count_with_subtree 0' do
            # An endpoint occupies fully seeded trees (e.g. Administrative Einheiten, >15,000
            # concepts) only to a fraction. With a default of 0 the productive selection drowned in a
            # full-dump list; the default of 1 makes "does not occur in the endpoint" evaluable.
            empty_concept = @concept_scheme.concepts.where.not(id: @concept.id).first
            skip 'tree needs a second, unused alias' if empty_concept.blank?

            default_ids = call_tool('facet_values', { 'classification_tree_label_id' => @concept_scheme.id })['values'].pluck('id')

            assert_includes default_ids, @concept.id
            assert_not_includes default_ids, empty_concept.id

            with_empty_ids = call_tool('facet_values', { 'classification_tree_label_id' => @concept_scheme.id, 'min_count_with_subtree' => 0 })['values'].pluck('id')

            assert_includes with_empty_ids, empty_concept.id
          end

          test 'statistics returns the real content count grouped by day' do
            result = call_tool('statistics', { 'attribute' => 'dct:created', 'group_by' => 'day' })
            day_total = result['data'].sum { |bucket| bucket['y'] }

            assert_equal 2, day_total
          end

          test 'suggest returns a well-formed suggestions payload' do
            result = call_tool('suggest', { 'text' => 'Alpha' })

            assert_kind_of Array, result['suggestions']
          end

          test 'suggest_by_title returns a well-formed suggestions payload' do
            result = call_tool('suggest_by_title', { 'text' => 'Alpha' })

            assert_kind_of Array, result['suggestions']
          end

          test 'suggest respects the limit argument' do
            result = call_tool('suggest', { 'text' => 'Alpha', 'limit' => 1 })

            assert_equal 1, result['suggestions'].size
          end

          test 'search_contents count reflects the true total, not the limit-capped page size' do
            # The setup has 2 articles (@content1/@content2). With limit=1 count still has to be 2
            # (the real total) and returned/items only 1 -- otherwise the value is no good for
            # counting.
            result = call_tool('search_contents', { 'limit' => 1 })

            assert_equal 2, result['count']
            assert_equal 1, result['returned']
            assert_equal 1, result['items'].size
          end

          test 'search_contents count is locale-independent: content without a default-locale translation still counts' do
            # Regression: the endpoint MCP is entity-centric, so the count has to cover the WHOLE
            # endpoint. Before the fix, base_query scoped to the default locale (de) -> contents
            # without a de translation were missing from the count. An en-only article therefore has
            # to lift the total from 2 to 3 (McpController#create sets language 'all' -> no locale
            # filter).
            I18n.with_locale(:en) do
              create_content('Artikel', { name: 'MCP English Only' }, @creator)
            end

            result = call_tool('search_contents', {})

            assert_equal 3, result['count']
          end

          test 'list_attributes lists advanced-search attributes with their type and label' do
            result = call_tool('list_attributes', {})

            entry = result['attributes'].find { |a| a['attribute'] == 'alternativeHeadline' }

            assert_not_nil entry, "expected alternativeHeadline in #{result['attributes']}"
            assert_equal 'string', entry['type']
            assert_predicate entry['label'], :present?
          end

          test 'list_attributes exposes the unit of a numeric attribute so values can be converted before filtering' do
            # Without a unit a numeric filter is not safely usable: the stored value is in the
            # property's unit (pixels here, metres for tours) while the user asks in another unit
            # ("under 15 km"). A client without a unit passes the number unconverted and gets 0 hits.
            attributes = DataCycleCore::Mcp::AttributeFilter.new.available(['Video'])
            entry = attributes.find { |a| a[:attribute] == 'width' }

            assert_not_nil entry, "expected width in #{attributes}"
            assert_equal 'pixel', entry[:unit]
          end

          test 'list_attributes omits a label that is an i18n key hash instead of leaking the raw hash' do
            # Overlay properties carry { key:, key_suffix: } as their label; resolving that needs a
            # content instance, which the discovery does not have.
            attributes = DataCycleCore::Mcp::AttributeFilter.new.available

            assert(attributes.none? { |a| a[:label].is_a?(::Hash) }, 'expected no Hash labels in the discovery payload')
          end

          test 'search_contents filters by a structured attribute condition instead of full-text' do
            match = create_content('Artikel', { name: 'MCP Attr Match', alternative_headline: 'ZzMarkerZz' }, @creator)
            create_content('Artikel', { name: 'MCP Attr NoMatch', alternative_headline: 'nothing here' }, @creator)

            result = call_tool('search_contents', { 'attributes' => [{ 'attribute' => 'alternativeHeadline', 'in' => { 'like' => 'ZzMarkerZz' } }] })

            assert_equal [match.id], result['items'].pluck('id')
            assert_equal 1, result['count']
          end

          test 'search_contents filters by positive and negative classification facets' do
            # @content1 carries @concept, @content2 does not.
            include_result = call_tool('search_contents', { 'classification_alias_ids' => [@concept.id] })

            assert_equal [@content1.id], include_result['items'].pluck('id')

            exclude_result = call_tool('search_contents', { 'exclude_classification_alias_ids' => [@concept.id] })
            exclude_ids = exclude_result['items'].pluck('id')

            assert_includes exclude_ids, @content2.id
            assert_not_includes exclude_ids, @content1.id
          end

          test 'search_contents ANDs classification_alias_id_groups and ORs within a group' do
            # A shared classification_alias_ids list is OR-combined and cannot express "condition A
            # AND condition B" -- it returns more hits instead of fewer. That is exactly what requests
            # like "difficulty medium AND region X AND category hiking" failed on.
            second_concept = @concept_scheme.concepts.where.not(id: @concept.id).first
            skip 'tree needs a second alias' if second_concept.blank?

            first_only = create_content('Artikel', { name: 'MCP Group First', tags: [@concept.id] }, @creator)
            second_only = create_content('Artikel', { name: 'MCP Group Second', tags: [second_concept.id] }, @creator)
            both = create_content('Artikel', { name: 'MCP Group Both', tags: [@concept.id, second_concept.id] }, @creator)

            or_ids = call_tool('search_contents', { 'classification_alias_ids' => [@concept.id, second_concept.id] })['items'].pluck('id')

            assert_includes or_ids, first_only.id
            assert_includes or_ids, second_only.id
            assert_includes or_ids, both.id

            and_ids = call_tool('search_contents', { 'classification_alias_id_groups' => [[@concept.id], [second_concept.id]] })['items'].pluck('id')

            assert_includes and_ids, both.id
            assert_not_includes and_ids, first_only.id
            assert_not_includes and_ids, second_only.id
          end

          test 'search_contents treats classification_alias_ids as an additional AND group alongside the groups' do
            second_concept = @concept_scheme.concepts.where.not(id: @concept.id).first
            skip 'tree needs a second alias' if second_concept.blank?

            both = create_content('Artikel', { name: 'MCP Mixed Both', tags: [@concept.id, second_concept.id] }, @creator)
            create_content('Artikel', { name: 'MCP Mixed One', tags: [@concept.id] }, @creator)

            result = call_tool('search_contents', {
              'classification_alias_ids' => [@concept.id],
              'classification_alias_id_groups' => [[second_concept.id]]
            })

            assert_equal [both.id], result['items'].pluck('id')
          end

          test 'search_contents applies the near geo-radius filter when provided' do
            geo_content = create_content('Örtlichkeit', { name: 'MCP Geo Content', location: RGeo::Geographic.spherical_factory(srid: 4326).point(10, 10) }, @creator)
            geo_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp geo test',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel', 'Örtlichkeit'] }]
            )

            near_result = call_tool('search_contents', { 'near' => { 'lat' => 10, 'lon' => 10, 'radius_km' => 1 } }, endpoint_id: geo_endpoint.id)

            assert_equal [geo_content.id], near_result['items'].pluck('id')

            far_result = call_tool('search_contents', { 'near' => { 'lat' => 50, 'lon' => 50, 'radius_km' => 1 } }, endpoint_id: geo_endpoint.id)

            assert_equal 0, far_result['count']
          end

          test 'search_contents filters by presence/absence of a relation (has_relations/missing_relations)' do
            image = create_content('Bild', { name: 'MCP Test Image' }, @creator)

            with_image = create_content('Artikel', { name: 'MCP Test With Image', image: [image.id] }, @creator)
            without_image = create_content('Artikel', { name: 'MCP Test Without Image' }, @creator)

            has_result = call_tool('search_contents', { 'has_relations' => ['image'] })

            assert_equal [with_image.id], has_result['items'].pluck('id')

            missing_result = call_tool('search_contents', { 'missing_relations' => ['image'] })

            assert_includes missing_result['items'].pluck('id'), without_image.id
            assert_not_includes missing_result['items'].pluck('id'), with_image.id
          end

          test 'list_templates lists the templates present in the endpoint with their counts' do
            # Without this discovery the TYPE of a content is guesswork: a client cannot see that a
            # type named by the user (e.g. FoodEstablishment) is absent from the endpoint and that the
            # fact is modelled as a category instead.
            mixed_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp list templates test',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel', 'Bild'] }]
            )
            create_content('Bild', { name: 'MCP Template Image' }, @creator)

            result = call_tool('list_templates', {}, endpoint_id: mixed_endpoint.id)
            counts = result['templates'].to_h { |t| [t['template_name'], t['count']] }

            assert_includes counts.keys, 'Artikel'
            assert_includes counts.keys, 'Bild'
            assert_operator counts['Artikel'], :>, 0
            # Descending by count -- the endpoint's load-bearing types come first.
            assert_equal counts.values.sort.reverse, counts.values
            # A template the endpoint does not carry is absent from the list (rather than having
            # count 0): that is exactly what makes "this type is not modelled here" recognisable.
            assert_not_includes counts.keys, 'Video'
          end

          # Without an argument describe_endpoint describes the endpoint the client is attached to --
          # it cannot name it at all, it knows only the URL it is connected under.
          test 'describe_endpoint without arguments profiles the endpoint of this mount' do
            result = call_tool('describe_endpoint', {})

            assert_equal @endpoint.id, result.dig('endpoint', 'id')
            assert result.dig('endpoint', 'queryable_here')
            assert_equal call_tool('list_templates', {})['templates'], result['templates']
            assert_equal DataCycleCore::Mcp::Servers::SingleEndpointServer::TOOLS.map(&:tool_name), result['tools'].pluck('tool')
          end

          # A FOREIGN endpoint named by id is described but is not queryable from this mount:
          # search_contents and friends keep running over the result space of THIS server. Without
          # queryable_here a client reads the profile as a promise and subsequently reports numbers
          # from the wrong endpoint.
          test 'describe_endpoint profiles a foreign endpoint by id and marks it as not queryable here' do
            foreign = DataCycleCore::StoredFilter.create!(
              name: 'mcp describe endpoint foreign',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Bild'] }]
            )
            create_content('Bild', { name: 'MCP Describe Endpoint Image' }, @creator)

            result = call_tool('describe_endpoint', { 'endpoint_id' => foreign.id })

            assert_equal foreign.id, result.dig('endpoint', 'id')
            assert_not result.dig('endpoint', 'queryable_here')
            assert_equal ['Bild'], result['templates'].pluck('template_name')
          end

          # Only what the user would be allowed to query is describable (the same scope as
          # list_endpoints). An unreleased endpoint becomes an error response and not, silently, the
          # profile of its own mount -- that would look like an answer to the question asked.
          test 'describe_endpoint rejects an endpoint the user may not query' do
            private_endpoint = DataCycleCore::StoredFilter.create!(name: 'mcp describe endpoint private', user_id: @creator.id, api: false)

            body = call_tool_raw('describe_endpoint', { 'endpoint_id' => private_endpoint.id })

            assert body.dig('result', 'isError')
          end

          test 'search_contents restricts results to the requested template, so another type is not counted in' do
            # The case from practice: a category facet from a tree that classifies several types
            # counts contents of other types along (accommodations on a restaurant question). Without
            # template_names the type could not be narrowed at all.
            shared_concept = @concept_scheme.concepts.first
            article = create_content('Artikel', { name: 'MCP Type Article', tags: [shared_concept.id] }, @creator)
            image = create_content('Bild', { name: 'MCP Type Image', tags: [shared_concept.id] }, @creator)

            mixed_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp template filter test',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel', 'Bild'] }]
            )

            both = call_tool('search_contents', { 'classification_alias_ids' => [shared_concept.id] }, endpoint_id: mixed_endpoint.id)

            assert_includes both['items'].pluck('id'), article.id
            assert_includes both['items'].pluck('id'), image.id

            only_images = call_tool(
              'search_contents',
              { 'classification_alias_ids' => [shared_concept.id], 'template_names' => ['Bild'] },
              endpoint_id: mixed_endpoint.id
            )

            assert_equal [image.id], only_images['items'].pluck('id')
            assert_equal 1, only_images['count']
            assert_equal ['Bild'], only_images.dig('applied_filters', 'template_names')
          end

          test 'facet_values exposes the tree structure, so a grouping node is distinguishable from its children' do
            # Rendered flat, parent and child nodes look equal in rank and a client cannot tell that a
            # filter on the parent pulls the whole subtree along. That is exactly where hit counts
            # diverge for the same question (Wandern vs. Bergsteigen).
            child = @concept_scheme.create_concept('MCP Structure Parent', 'MCP Structure Child')
            parent = child.parent
            create_content('Artikel', { name: 'MCP Structure Content', tags: [child.id] }, @creator)

            values = call_tool('facet_values', { 'classification_tree_label_id' => @concept_scheme.id })['values'].index_by { |v| v['id'] }

            assert_equal parent.id, values.dig(child.id, 'parent_id')
            assert values.dig(child.id, 'is_leaf')

            assert_nil values.dig(parent.id, 'parent_id')
            assert_not values.dig(parent.id, 'is_leaf')
            # A pure grouping node: it counts over the subtree and carries no content itself.
            assert_equal 1, values.dig(parent.id, 'thing_count_with_subtree')
            assert_equal 0, values.dig(parent.id, 'thing_count_without_subtree')
          end

          test 'search_contents reports the resolved filter including the concepts pulled in by the subtree' do
            # Without applied_filters a hit count is not verifiable: that the filter on the parent
            # includes the child too stands nowhere else in the response.
            child = @concept_scheme.create_concept('MCP Applied Parent', 'MCP Applied Child')
            parent = child.parent
            create_content('Artikel', { name: 'MCP Applied Content', tags: [child.id] }, @creator)

            result = call_tool('search_contents', { 'classification_alias_id_groups' => [[parent.id]] })
            group = result.dig('applied_filters', 'classification_groups', 0)

            assert_equal [parent.id], group['concepts'].pluck('id')
            assert_equal 'MCP Applied Parent', group.dig('concepts', 0, 'name')
            assert group['include_subtree']
            assert_includes group['subtree_concepts'].pluck('id'), child.id
            assert_equal 1, group['subtree_concept_count']
            assert_not group['subtree_concepts_truncated']
          end

          test 'search_contents applied_filters omits the subtree concepts when include_subtree is false' do
            child = @concept_scheme.create_concept('MCP Exact Parent', 'MCP Exact Child')
            parent = child.parent

            result = call_tool('search_contents', { 'classification_alias_ids' => [parent.id], 'include_subtree' => false })
            group = result.dig('applied_filters', 'classification_groups', 0)

            assert_not group['include_subtree']
            assert_nil group['subtree_concepts']
          end

          test 'search_contents applied_filters names ids that resolve to no concept instead of filtering silently' do
            # A UUID without a concept (typically a classification id instead of an alias id) filters
            # nothing. Without feedback the result looks like a validly filtered one.
            unknown_id = SecureRandom.uuid

            envelope = call_tool_envelope('search_contents', { 'classification_alias_ids' => [unknown_id] })
            group = envelope.dig('data', 'applied_filters', 'classification_groups', 0)

            assert_equal [unknown_id], group['unresolved_ids']
            assert_empty group['concepts']
            # The per-group entry says WHICH condition lost the id; the envelope warning is what a
            # client sees without digging for it, and names the id so the two can be matched up.
            assert_includes envelope['warnings'].to_a.join(' '), unknown_id
          end

          test 'search_contents warns nothing when every passed concept resolves' do
            envelope = call_tool_envelope('search_contents', {})

            assert_not envelope.key?('warnings'), "a call without warnings must omit the key, was: #{envelope['warnings'].inspect}"
          end

          # unresolved_ids above covers only the well-formed unknown UUID. The likelier mistake is the
          # concept NAME instead of the id -- that ran all the way into Mcp::FilterDescription's
          # ::uuid[] cast and came back as a PG::InvalidTextRepresentation: an error out of the
          # diagnostics meant to explain precisely that input, and with no hint at the cause. Now the
          # schema rejects it and the message names the parameter.
          test 'search_contents rejects a concept name passed as a classification alias id' do
            body = call_tool_raw('search_contents', { 'classification_alias_ids' => ['wandern'] })

            assert body.dig('result', 'isError')
            assert_includes body.dig('result', 'content', 0, 'text'), 'classification_alias_ids'
          end

          # Counter-check: the nested group form is validated at the same place -- there the element
          # shape sits one level deeper and would be easy to overlook.
          test 'search_contents rejects a concept name inside a classification alias id group' do
            body = call_tool_raw('search_contents', { 'classification_alias_id_groups' => [['wandern']] })

            assert body.dig('result', 'isError')
            assert_includes body.dig('result', 'content', 0, 'text'), 'classification_alias_id_groups'
          end

          # The case the pattern alone does NOT reject: json_schemer compiles it into a Ruby regexp
          # whose ^/$ are line anchors -- a UUID with a second line appended satisfied "^<uuid>$" and
          # got through. It is rejected through the length (Mcp::UUID_CONSTRAINTS), not through the
          # pattern.
          test 'search_contents rejects a uuid with a second line appended' do
            body = call_tool_raw('search_contents', { 'classification_alias_ids' => ["#{SecureRandom.uuid}\nwandern"] })

            assert body.dig('result', 'isError')
            assert_includes body.dig('result', 'content', 0, 'text'), 'classification_alias_ids'
          end

          # The SINGULAR id was the bigger gap: it comes with format: 'uuid' from the OpenAPI document
          # and therefore counted as declared -- but the mcp gem does not validate format, so it got
          # through unchecked (the same held for all seven path parameters).
          test 'get_content rejects an id that is not a uuid' do
            body = call_tool_raw('get_content', { 'id' => 'wandern' })

            assert body.dig('result', 'isError')
            assert_includes body.dig('result', 'content', 0, 'text'), '/id'
          end

          test 'search_contents applied_filters carries the unit of a numeric attribute filter' do
            # The same unit list_attributes reports -- so the number in the filter ("max: 15000")
            # stays interpretable in the response and is not read as km.
            video_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp applied filters unit test',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Video'] }]
            )
            # The endpoint has to ACTUALLY contain the type: the attribute discovery derives its
            # template list from the contents, not from the filter definition. Without this video the
            # result space was empty, the discovery ran instance-wide, and "width" was resolved from
            # an arbitrary template -- sometimes pixel (Video/Bild/PDF), sometimes metre (the Product
            # mixin), depending on the database's row order.
            create_content('Video', { name: 'MCP Unit Test Video' }, @creator)

            result = call_tool(
              'search_contents',
              { 'attributes' => [{ 'attribute' => 'width', 'in' => { 'max' => 1920 } }] },
              endpoint_id: video_endpoint.id
            )
            entry = result.dig('applied_filters', 'attributes', 0)

            assert_equal 'width', entry['attribute']
            assert_equal 'pixel', entry['unit']
            assert_equal({ 'max' => 1920 }, entry['in'])
          end

          # The bug behind it: the discovery did not distinguish "no restriction" from "restricted to
          # nothing". An endpoint without contents returned [] as its template list, the scope fell
          # away and the discovery ran instance-wide -- the client was told attributes that do not
          # exist here and could not tell them from real ones.
          test 'list_attributes reports nothing for an empty endpoint instead of falling back to the whole instance' do
            empty_endpoint = DataCycleCore::StoredFilter.create!(
              name: 'mcp empty endpoint attributes test',
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Person'] }]
            )

            assert_empty call_tool('list_attributes', {}, endpoint_id: empty_endpoint.id)['attributes'],
                         'ein leerer Endpoint darf nicht die instanzweite Attributliste ausliefern'
            assert_predicate call_tool('list_attributes', {})['attributes'], :present?, 'the populated endpoint still returns its attributes'
          end

          test 'search_contents explain reports the count after every filter step, so a divergence is localizable' do
            # applied_filters shows WHAT was filtered; explain shows HOW MUCH each condition removes.
            # Without it a differing hit count is visible only as an overall result and the cause has
            # to be hunted by recomputing individual variants.
            second_concept = @concept_scheme.concepts.where.not(id: @concept.id).first
            skip 'tree needs a second alias' if second_concept.blank?

            create_content('Artikel', { name: 'MCP Explain Both', tags: [@concept.id, second_concept.id] }, @creator)
            create_content('Artikel', { name: 'MCP Explain First', tags: [@concept.id] }, @creator)

            result = call_tool('search_contents', {
              'classification_alias_id_groups' => [[@concept.id], [second_concept.id]],
              'explain' => true
            })
            steps = result.dig('applied_filters', 'explain')

            assert_equal 'endpoint', steps.first['filter']
            assert_equal ['classification_group'], steps.drop(1).pluck('filter').uniq
            assert_equal ['1/2', '2/2'], steps.drop(1).pluck('detail')
            # Cumulative and monotonically decreasing: every step can only take away.
            assert_equal steps.pluck('count').sort.reverse, steps.pluck('count')
            # The last step matches the reported total.
            assert_equal result['count'], steps.last['count']
            assert_operator steps.first['count'], :>, steps.last['count']
          end

          test 'search_contents omits explain unless it was requested' do
            # Diagnostics must not make every search more expensive -- every step costs its own COUNT.
            result = call_tool('search_contents', { 'classification_alias_ids' => [@concept.id] })

            assert_not result['applied_filters'].key?('explain')
          end

          test 'search_contents omits applied_filters keys for filters that were not passed' do
            # applied_filters must not claim that filtering happened: a call without facets has no
            # classification_groups.
            result = call_tool('search_contents', { 'query' => 'Alpha' })

            assert_equal 'Alpha', result.dig('applied_filters', 'query')
            assert_not result['applied_filters'].key?('classification_groups')
            assert_not result['applied_filters'].key?('attributes')
          end

          # ---- place / resolve_place -------------------------------------------------------
          # The geo cascade itself is checked in test/models/data_cycle_core/mcp/geo_scope_test.rb.
          # What matters here is the tool layer above it: that the place filter takes effect within the
          # endpoint scope, that an UNRESOLVABLE place appears as such in the response (rather than
          # passing as an unfiltered total), and that resolve_place makes the same result queryable up
          # front.
          #
          # @concept_scheme ('Tags') serves as the resolution tree here and @concept as the place: @content1
          # carries this classification, @content2 none -- so stage 1 of the cascade matches exactly
          # one content without a geo tree of its own being needed.
          def with_tags_as_geo_tree
            stub_geo_scope_feature(resolution_trees: [@concept_scheme.name])
            yield
          ensure
            reset_geo_scope_feature
          end

          test 'search_contents place filters within the endpoint and reports the resolved concept' do
            with_tags_as_geo_tree do
              result = call_tool('search_contents', { 'place' => @concept.internal_name })
              place = result.dig('applied_filters', 'place')

              assert_equal 1, result['count']
              assert_equal @content1.id, result.dig('items', 0, 'id')
              assert place['resolved']
              assert_equal @concept.internal_name, place['requested']
              assert_equal @concept.id, place['concept_id']
              assert_equal @concept_scheme.name, place['concept_scheme']
            end
          end

          # coverage assigns the hits to the stage that carried them -- a number from :address rests
          # on weaker evidence than one from :classification. It hangs on the same switch as the step
          # log because it has the same kind of cost: one COUNT per cascade stage. Without that
          # coupling, EVERY search with place paid three extra aggregates for a value needed only when
          # putting a number in context.
          test 'search_contents reports place coverage per cascade stage only when explain is requested' do
            with_tags_as_geo_tree do
              explained = call_tool('search_contents', { 'place' => @concept.internal_name, 'explain' => true })

              assert_equal 1, explained.dig('applied_filters', 'place', 'coverage', 'classification')
              assert_equal 0, explained.dig('applied_filters', 'place', 'coverage', 'address')
              # The place step appears in the log too, with the resolved place as its detail.
              assert_includes explained.dig('applied_filters', 'explain').pluck('filter'), 'place'

              plain = call_tool('search_contents', { 'place' => @concept.internal_name })

              assert plain.dig('applied_filters', 'place', 'resolved')
              assert_not plain.dig('applied_filters', 'place').key?('coverage')
            end
          end

          test 'search_contents names an unresolvable place instead of silently reporting the unfiltered total' do
            # The actual trap: if the filter does not take effect, the hit count is the endpoint's
            # total -- to be read as "that many exist in <place>" without this hint. The same role as
            # unresolved_ids on the facets.
            with_tags_as_geo_tree do
              result = call_tool('search_contents', { 'place' => 'Nirgendwo' })
              place = result.dig('applied_filters', 'place')

              assert_not place['resolved']
              assert_equal 'Nirgendwo', place['unresolved_place']
              assert_equal call_tool('search_contents', {})['count'], result['count']
            end
          end

          # The place name comes from an LLM. In LIKE semantics '%' and '_' would be wildcards, a
          # place: "%" would have resolved to an arbitrary concept and the filter would have applied
          # to a different region than the one asked for -- visible only as a plausible hit count.
          test 'search_contents does not resolve a place given as a LIKE wildcard' do
            with_tags_as_geo_tree do
              result = call_tool('search_contents', { 'place' => '%' })

              assert_not result.dig('applied_filters', 'place', 'resolved')
              assert_equal '%', result.dig('applied_filters', 'place', 'unresolved_place')
            end
          end

          test 'resolve_place reports the resolved concept with its per-stage coverage' do
            with_tags_as_geo_tree do
              result = call_tool('resolve_place', { 'place' => @concept.internal_name })

              assert_equal @concept.id, result['concept_id']
              assert_equal @concept_scheme.name, result['concept_scheme']
              assert_equal 1, result.dig('coverage', 'classification')
              # stages says which stages can decide anything for THIS place at all.
              assert_equal DataCycleCore::Mcp::GeoScope::STAGES.map(&:to_s), result['stages'].pluck('stage')
            end
          end

          test 'resolve_place names the searched trees when a place cannot be resolved' do
            # Without the searched trees, "not found" is indistinguishable from "the wrong tree is
            # configured", and a client cannot sensibly correct the place name.
            with_tags_as_geo_tree do
              result = call_tool('resolve_place', { 'place' => 'Nirgendwo' })

              assert_not result['resolved']
              assert_equal [@concept_scheme.name], result['searched_concept_schemes']
              assert_predicate result['error'], :present?
            end
          end

          # The flag from features.yml has to take effect: without a check, :enabled: false was a
          # setting without consequence and the place filter kept applying.
          test 'a disabled geo scope feature makes place inert instead of filtering anyway' do
            stub_geo_scope_feature(resolution_trees: [@concept_scheme.name], enabled: false)

            result = call_tool('search_contents', { 'place' => @concept.internal_name })

            assert_not result.dig('applied_filters', 'place', 'resolved')
            assert_equal call_tool('search_contents', {})['count'], result['count']
          ensure
            reset_geo_scope_feature
          end

          # applied_filters.place.resolved states it already, but nested where a client that reads
          # only the envelope does not look -- and count is the unfiltered total, the same trap
          # unresolved_concept_ids warns about.
          test 'search_contents warns in the envelope when a place name resolves to nothing' do
            with_tags_as_geo_tree do
              envelope = call_tool_envelope('search_contents', { 'place' => 'Nirgendwo' })

              assert_not envelope.dig('data', 'applied_filters', 'place', 'resolved')
              assert_equal call_tool('search_contents', {})['count'], envelope.dig('data', 'count')
              assert_includes envelope['warnings'].to_a.join(' '), 'Nirgendwo'

              resolved = call_tool_envelope('search_contents', { 'place' => @concept.internal_name })

              assert_not resolved.key?('warnings'), "a resolved place must not warn, was: #{resolved['warnings'].inspect}"
            end
          end

          test 'resources/read returns the schema of a template present in this endpoint' do
            jsonrpc_post('resources/read', { 'uri' => 'datacycle://schema/Artikel' }, token: @creator.access_token, endpoint_id: @endpoint.id)

            assert_response :success
            schema = JSON.parse(response.parsed_body.dig('result', 'contents', 0, 'text'))

            assert_equal 'Artikel', schema['title']
          end

          test 'resources/read on the schema index scopes templates to the endpoint' do
            jsonrpc_post('resources/read', { 'uri' => 'datacycle://schema' }, token: @creator.access_token, endpoint_id: @endpoint.id)

            assert_response :success
            index = JSON.parse(response.parsed_body.dig('result', 'contents', 0, 'text'))

            assert_equal ['Artikel'], index['templates']
          end

          test 'resolve_concepts unions all name variants of a term and reports the real union count' do
            # The documented failure case: the same fact exists as several concepts. Here variant A
            # carries two contents, variant B two (one of them the same) and variant C none. The sum
            # of the individual counts would be 4 and the strongest single variant 2 -- the correct
            # answer is the union, 3. Precisely that difference used to be invisible.
            variant_a = build_concept(@concept_scheme, 'Mcp Diet Variant A')
            variant_b = build_concept(@concept_scheme, 'Mcp Diet Variant B')
            variant_c = build_concept(@concept_scheme, 'Mcp Diet Variant C')
            shared = create_content('Artikel', { name: 'MCP Diet Shared', tags: [variant_a.id, variant_b.id] }, @creator)
            create_content('Artikel', { name: 'MCP Diet Only A', tags: [variant_a.id] }, @creator)
            create_content('Artikel', { name: 'MCP Diet Only B', tags: [variant_b.id] }, @creator)

            result = call_tool('resolve_concepts', { 'term' => 'Mcp Diet Variant' })

            assert_equal 3, result['count']
            assert_equal 2, result['largest_single_variant_count']
            assert_equal [variant_a.id, variant_b.id].to_set, result['classification_alias_id_group'].to_set
            assert_not_includes result['classification_alias_id_group'], variant_c.id

            empty_entry = result['concepts'].find { |c| c['id'] == variant_c.id }

            assert_not empty_entry['in_group']
            # Translated text rather than a literal: the exclusion reason follows the mount's language
            # like every other client-visible text (it used to stand as an English literal beside a
            # German warning in the same response).
            assert_equal DataCycleCore::Mcp::Translations.t('concept_resolver.excluded.empty'), empty_entry['excluded_reason']
            # Counter-check that the group can be passed through to search_contents unchanged.
            searched = call_tool('search_contents', { 'classification_alias_id_groups' => [result['classification_alias_id_group']] })

            assert_equal 3, searched['count']
            assert_includes searched['items'].pluck('id'), shared.id
          end

          # The term comes from an LLM and lands in an ILIKE pattern. Unescaped, '%' and '_' are
          # wildcards: term '%' returned the concepts of the whole endpoint as a group, with a union
          # count that looks like an answer. Measured against the dev instance, '%' thereby matched
          # 27,846 aliases instead of the 10 that really carry a percent sign in their name.
          test 'resolve_concepts treats wildcards in the term as literal characters' do
            literal = build_concept(@concept_scheme, 'Mcp Wildcard 100% Bio')
            other = build_concept(@concept_scheme, 'Mcp Wildcard Ordinary')
            create_content('Artikel', { name: 'MCP Wildcard Literal', tags: [literal.id] }, @creator)
            create_content('Artikel', { name: 'MCP Wildcard Other', tags: [other.id] }, @creator)

            result = call_tool('resolve_concepts', { 'term' => '%' })

            assert_not_includes result['concepts'].pluck('id'), other.id, "'%' must not act as a wildcard"
            assert_includes result['concepts'].pluck('id'), literal.id, "'%' must find the concept containing a percent sign"
          end

          test 'resolve_concepts drops a variant whose ancestor is already in the group' do
            # Parent AND child nodes in one group filter the same set (include_subtree) but read as
            # two conditions. The child node is excluded with a stated reason.
            parent = build_concept(@concept_scheme, 'Mcp Nested Term Parent')
            child = build_concept(@concept_scheme, 'Mcp Nested Term Child', parent_concept: parent)
            create_content('Artikel', { name: 'MCP Nested Child Content', tags: [child.id] }, @creator)

            result = call_tool('resolve_concepts', { 'term' => 'Mcp Nested Term' })

            assert_equal [parent.id], result['classification_alias_id_group']

            child_entry = result['concepts'].find { |c| c['id'] == child.id }

            assert_not child_entry['in_group']
            assert_includes child_entry['excluded_reason'], 'redundant'
          end

          test 'resolve_concepts reports no count but a warning when nothing is filterable' do
            # The most dangerous case, because it produces a number that is too HIGH: every name match
            # is empty in this endpoint, so the group is []. count used to return the endpoint's total
            # -- "no match" turned into "every content carries the term", without an error message.
            # Counter-check below: precisely this group filters nothing away in search_contents, so an
            # empty group must never be passed on as a filter.
            build_concept(@concept_scheme, 'Mcp Unfilterable Term A')
            build_concept(@concept_scheme, 'Mcp Unfilterable Term B')

            envelope = call_tool_envelope('resolve_concepts', { 'term' => 'Mcp Unfilterable Term' })
            result = envelope['data']

            assert_empty result['classification_alias_id_group']
            assert_not result.key?('count'), "count may be absent for an empty group, was: #{result['count'].inspect}"
            # In the envelope and no longer in the payload: a client that reads only `data` would
            # have seen an empty group with no statement about it.
            assert_not result.key?('warning'), 'the empty-group warning belongs in the envelope'
            assert_includes envelope['warnings'].to_a.join(' '), 'LEER'
            empty_entries = result['concepts'].select { |c| c['excluded_reason'] == DataCycleCore::Mcp::Translations.t('concept_resolver.excluded.empty') }

            assert_equal 2, empty_entries.size

            unfiltered = call_tool('search_contents', { 'classification_alias_id_groups' => [result['classification_alias_id_group']] })
            endpoint_total = call_tool('search_contents', {})

            assert_equal endpoint_total['count'], unfiltered['count']
          end

          private

          # Creates a concept in the given scheme -- the MCP tools count through
          # collected_concept_contents, which is only filled by a real assignment.
          def build_concept(concept_scheme, name, parent_concept: nil)
            concept = DataCycleCore::Concept.new(concept_scheme:, parent_concept:)
            I18n.available_locales.each { |l| I18n.with_locale(l) { concept.name = name } }
            concept.save!
            concept.reload
          end

          # Video carries width as a numeric advanced_search attribute with a unit (pixel) -- so the
          # sort tests cover the same attribute path as the unit test above.
          def video_endpoint_with_widths(widths)
            widths.each_with_index { |width, index| create_content('Video', { name: "MCP Sort #{index}", width: }, @creator) }

            DataCycleCore::StoredFilter.create!(
              name: "mcp sort test #{SecureRandom.hex(4)}",
              user_id: @creator.id,
              api: true,
              parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Video'] }]
            )
          end

          def call_tool(name, arguments, endpoint_id: @endpoint.id)
            call_tool_envelope(name, arguments, endpoint_id:)&.dig('data')
          end

          def call_tool_envelope(name, arguments, endpoint_id: @endpoint.id)
            call_tool_raw(name, arguments, endpoint_id:).dig('result', 'structuredContent')
          end

          def call_tool_raw(name, arguments, endpoint_id: @endpoint.id)
            jsonrpc_post('tools/call', { 'name' => name, 'arguments' => arguments }, token: @creator.access_token, endpoint_id:)

            assert_response :success
            response.parsed_body
          end
        end
      end
    end
  end
end
