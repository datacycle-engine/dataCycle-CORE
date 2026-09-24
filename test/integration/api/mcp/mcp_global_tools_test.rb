# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module Mcp
      # Functional tests for the GlobalServer tools: proves that tools/call and resources/read
      # return correct data derived from real content/endpoints, not just a 200 -- complements
      # mcp_global_authorization_test.rb, which only proves the access boundary.
      class McpGlobalToolsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        include DataCycleCore::McpTestHelper

        before(:all) do
          DataCycleCore::Thing.delete_all

          @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          @user.update!(access_token: SecureRandom.hex) if @user.access_token.blank?

          @content1 = create_content('Artikel', { name: 'MCP Global Test Alpha' }, @user)
          @content2 = create_content('Artikel', { name: 'MCP Global Test Beta' }, @user)

          @concept_scheme = DataCycleCore::ConceptScheme.find_by(name: 'Tags')

          @endpoint = DataCycleCore::StoredFilter.create!(
            name: 'mcp global tools test',
            user_id: @user.id,
            api: true,
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel'] }]
          )
        end

        # initialize is the only call that delivers the server instructions (tools/list does not,
        # tools/call does not). Without this test a bug in the instructions assembly -- a missing
        # interpolation, say -- would surface only when a real client connects, because no other call
        # touches the field. Here it additionally runs through the real transport rather than only
        # through the constructor as in the unit test.
        test 'initialize delivers the server instructions for the instance-wide scope' do
          jsonrpc_post(
            'initialize',
            { 'protocolVersion' => '2025-06-18', 'capabilities' => {}, 'clientInfo' => { 'name' => 'mcp-test-client', 'version' => '1' } },
            token: @user.access_token
          )

          assert_response :success

          instructions = response.parsed_body.dig('result', 'instructions')

          assert_predicate instructions, :present?
          assert_includes instructions, DataCycleCore::Mcp::Translations.t('instructions.global', locale: I18n.default_locale)
          assert_includes instructions, DataCycleCore::Mcp::Translations.t('instructions.read_only', locale: I18n.default_locale)
          assert_not_includes instructions, 'translation missing'
        end

        # prompts/list and prompts/get bypass tools/call -- a bug in the prompt assembly (a missing
        # interpolation, say) would otherwise surface only when a user picks the prompt in the
        # client. Here it runs through the real transport rather than only through the constructor.
        test 'prompts/list and prompts/get deliver a usable prompt through the transport' do
          jsonrpc_post('prompts/list', {}, token: @user.access_token)

          assert_response :success
          assert_includes response.parsed_body.dig('result', 'prompts').pluck('name'), 'inventory_question'

          jsonrpc_post(
            'prompts/get',
            { 'name' => 'inventory_question', 'arguments' => { 'question' => 'Wie viele Artikel gibt es?' } },
            token: @user.access_token
          )

          assert_response :success

          message = response.parsed_body.dig('result', 'messages', 0)

          assert_equal 'user', message['role']
          assert_includes message.dig('content', 'text'), 'Wie viele Artikel gibt es?'
          assert_not_includes message.dig('content', 'text'), 'translation missing'
        end

        # The write prompt must not stand in the selection list without the write tools.
        test 'prompts/list hides the write prompt while write_enabled is off' do
          jsonrpc_post('prompts/list', {}, token: @user.access_token)

          assert_not_includes response.parsed_body.dig('result', 'prompts').pluck('name'), 'write_content'
        end

        test 'get_content returns the full content for a known id' do
          result = call_tool('get_content', { 'id' => @content1.id })

          assert_equal @content1.id, result['id']
        end

        test 'select_things returns exactly the requested contents' do
          result = call_tool('select_things', { 'ids' => [@content1.id, @content2.id] })

          assert_equal [@content1.id, @content2.id].sort, result['items'].pluck('id').sort
        end

        # select_things' `ids` was not called `*_ids` and was therefore the parameter neither the
        # declaration nor the contract test caught -- it accepted any string and answered with 0 hits
        # (Rails casts the non-UUID to NULL), i.e. with "does not exist" to an input that was never
        # an id.
        test 'select_things rejects ids that are not uuids' do
          body = call_tool_raw('select_things', { 'ids' => ['wandern'] })

          assert body.dig('result', 'isError')
          assert_includes body.dig('result', 'content', 0, 'text'), 'ids'
        end

        test 'universal_lookup resolves a known content id to a thing descriptor' do
          result = call_tool('universal_lookup', { 'id' => @content1.id })

          assert_equal 'thing', result['type']
          assert_equal @content1.id, result['id']
        end

        test 'universal_lookup returns an error descriptor for an unknown id' do
          result = call_tool('universal_lookup', { 'id' => SecureRandom.uuid })

          assert_predicate result['error'], :present?
        end

        test 'list_endpoints lists the api:true endpoint created by the calling user' do
          result = call_tool('list_endpoints', {})

          assert_includes result['endpoints'].pluck('id'), @endpoint.id
        end

        # On the global mount the endpoint is the only choice a client makes before it knows anything
        # about the contents -- with id and name alone it guesses from the name. Both are checked:
        # that the maintained values arrive, and that an unmaintained field is ABSENT rather than
        # standing there empty ("not maintained" has to stay distinguishable from "maintained and
        # empty", or a client reads the empty facet list as "this endpoint has no facets" -- it has
        # them, list_facets merely derives them there).
        test 'list_endpoints delivers the maintained description and curation, and omits what is unmaintained' do
          bare = call_tool('list_endpoints', {})['endpoints'].detect { |e| e['id'] == @endpoint.id }

          assert_not bare.key?('description'), 'an unmaintained description must not produce a field'
          assert_not bare.key?('concept_schemes'), 'uncurated facets must not produce a field'

          described = DataCycleCore::StoredFilter.create!(
            name: 'mcp global tools test described',
            user_id: @user.id,
            api: true,
            description: '<p>Touren und Wanderwege des Landes.</p>',
            language: ['de'],
            concept_scheme_ids: [@concept_scheme.id],
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Artikel'] }]
          )

          entry = call_tool('list_endpoints', {})['endpoints'].detect { |e| e['id'] == described.id }

          assert_equal 'Touren und Wanderwege des Landes.', entry['description'], 'markup does not belong in the response'
          assert_equal ['de'], entry['language']
          assert_equal [@concept_scheme.id], entry['concept_schemes'].pluck('id')
          assert_equal [@concept_scheme.name], entry['concept_schemes'].pluck('name')
        end

        test 'get_schema returns the real schema of a known template' do
          result = call_tool('get_schema', { 'template' => 'Artikel' })

          assert_equal 'Artikel', result['title']
        end

        test 'get_schema without a template lists the available templates' do
          result = call_tool('get_schema', {})

          assert_includes result['templates'], 'Artikel'
        end

        test 'browse_concept_schemes lists a known concept scheme and narrows it via search' do
          all_result = call_tool('browse_concept_schemes', {})

          assert_includes all_result['schemes'].pluck('id'), @concept_scheme.id

          matching_result = call_tool('browse_concept_schemes', { 'search' => @concept_scheme.name })

          assert_includes matching_result['schemes'].pluck('id'), @concept_scheme.id

          no_match_result = call_tool('browse_concept_schemes', { 'search' => 'no-such-scheme-zzz' })

          assert_empty no_match_result['schemes']
        end

        test 'browse_concept_schemes separates a tree structure from its coverage in the caller scope' do
          # The case the separated metrics are built for (see Mcp::ConceptSchemeMetrics): 'Tags' is
          # seeded but carries not a single content here -- no content of this test is tagged.
          # concept_count > 0 with thing_count 0 says exactly that. Were only one number to come
          # back, the tree would look like a usable filter candidate that then returns 0 hits -- which
          # until now stood as "carries 0 contents and has no effect" in the hand-written definition
          # and went stale with every import.
          scheme = call_tool('browse_concept_schemes', {})['schemes'].detect { |s| s['id'] == @concept_scheme.id }

          assert_operator scheme['concept_count'], :>, 0
          assert_equal 0, scheme['thing_count']
          assert_operator scheme['depth'], :>=, 1
        end

        test 'list_concepts lists the root concepts of a concept scheme' do
          result = call_tool('list_concepts', { 'concept_scheme_id' => @concept_scheme.id })

          assert_kind_of Array, result['concepts']
          assert_equal @concept_scheme.concepts.roots.count, result['concepts'].size
        end

        test 'list_concepts reports a content count per concept, so an unpopulated variant is distinguishable' do
          # A search for a user term often returns several concepts (the same thing from different
          # import sources). Without a number beside them a client takes the first match and reports a
          # plausible but far too low figure -- 17 instead of 81 in the vegan case.
          used = @concept_scheme.concepts.first
          unused = @concept_scheme.concepts.where.not(id: used.id).first
          skip 'tree needs two aliases' if unused.blank?

          create_content('Artikel', { name: 'MCP Concept Count', tags: [used.id] }, @user)

          counts = call_tool('list_concepts', { 'concept_scheme_id' => @concept_scheme.id })['concepts']
            .to_h { |c| [c['id'], c['thing_count']] }

          assert_equal 1, counts[used.id]
          assert_equal 0, counts[unused.id]
        end

        # The shared base_query tools on the global mount: the same code as on the endpoint server,
        # only with Mcp::ApiScope as the result space (see Servers::Base::SCOPED_TOOLS).
        test 'search_contents searches instance-wide and reports the real total' do
          result = call_tool('search_contents', {})

          assert_equal 2, result['count']
          assert_includes result['items'].pluck('id'), @content1.id
        end

        test 'search_contents applies its filters instance-wide instead of returning everything' do
          result = call_tool('search_contents', { 'query' => 'Alpha' })

          assert_equal 1, result['count']
          assert_equal [@content1.id], result['items'].pluck('id')
        end

        test 'list_facets derives the concept schemes from the visible contents when there is no endpoint' do
          concept = @concept_scheme.concepts.first
          create_content('Artikel', { name: 'MCP Global Facet', tags: [concept.id] }, @user)

          result = call_tool('list_facets', {})

          assert_includes result['schemes'].pluck('id'), @concept_scheme.id
        end

        test 'list_templates reports the templates present instance-wide' do
          result = call_tool('list_templates', {})

          assert_includes result['templates'].pluck('template_name'), 'Artikel'
        end

        # The query history (Mcp::QueryLog): the transport runs stateless, and without this log a
        # follow-up call cannot pick up on an earlier query.
        test 'recent_queries returns the previous tool call with its arguments and count' do
          call_tool('search_contents', { 'query' => 'Alpha' })

          result = call_tool('recent_queries', {})
          entry = result['queries'].first

          assert_equal 'search_contents', entry['tool']
          assert_equal({ 'query' => 'Alpha' }, entry['arguments'])
          assert_equal 1, entry['count']
        end

        test 'recent_queries reports no endpoint for a query made on the global mount' do
          call_tool('search_contents', {})

          entry = call_tool('recent_queries', { 'tool' => 'search_contents' })['queries'].first

          assert_nil entry['endpoint']
        end

        # The history is the USER's, not a mount's: they ask their question on the endpoint server and
        # pick up on the global one (or the other way round).
        test 'recent_queries also contains queries made on an endpoint mount, with the endpoint named' do
          jsonrpc_post('tools/call', { 'name' => 'search_contents', 'arguments' => {} }, token: @user.access_token, endpoint_id: @endpoint.id)

          assert_response :success

          entry = call_tool('recent_queries', { 'tool' => 'search_contents' })['queries'].first

          assert_equal @endpoint.id, entry.dig('endpoint', 'id')
        end

        test 'recent_queries narrows the history to a single tool' do
          call_tool('search_contents', {})
          call_tool('list_templates', {})

          result = call_tool('recent_queries', { 'tool' => 'search_contents' })

          assert_equal ['search_contents'], result['queries'].pluck('tool').uniq
        end

        test 'recent_queries logs a failed call too, so it is not repeated blindly' do
          call_tool('get_content', { 'id' => SecureRandom.uuid })

          entry = call_tool('recent_queries', { 'tool' => 'get_content' })['queries'].first

          assert_predicate entry['error'], :present?
        end

        # The boundary of the history, pinned rather than assumed: the mcp gem validates the
        # input_schema BEFORE tool.call, so a call rejected at the schema never reaches the tool block
        # (and therefore Mcp::QueryLog). Anyone relying on recent_queries to avoid repeating a failed
        # attempt does not see precisely the likeliest LLM mistake -- the mistyped parameter name.
        # Changing that would only be possible at the transport, not in the tool.
        test 'a call rejected by the input schema does not appear in the history' do
          jsonrpc_post('tools/call', { 'name' => 'search_contents', 'arguments' => { 'template_name' => 'Artikel' } }, token: @user.access_token)

          assert_response :success
          assert_predicate response.parsed_body.dig('result', 'isError'), :present?

          entries = call_tool('recent_queries', { 'tool' => 'search_contents' })['queries']

          assert_empty(entries.select { |entry| entry.dig('arguments', 'template_name').present? })
        end

        test 'recent_queries does not record itself' do
          call_tool('recent_queries', {})

          result = call_tool('recent_queries', {})

          assert_empty(result['queries'].select { |query| query['tool'] == 'recent_queries' })
        end

        test 'resources/read returns the schema of a template via the schema_template resource' do
          jsonrpc_post('resources/read', { 'uri' => 'datacycle://schema/Artikel' }, token: @user.access_token)

          assert_response :success
          schema = JSON.parse(response.parsed_body.dig('result', 'contents', 0, 'text'))

          assert_equal 'Artikel', schema['title']
        end

        # This resource's endpoint scope hangs off :stored_filter, not off :base_query -- the latter
        # exists on both mounts since the shared tools. Tied to :base_query, the resource would return
        # only the templates WITH contents instance-wide (here: 'Artikel' alone) and thereby a
        # different answer than get_schema gives to the same question.
        test 'resources/read on the schema index lists the same instance-wide templates as get_schema' do
          jsonrpc_post('resources/read', { 'uri' => 'datacycle://schema' }, token: @user.access_token)

          assert_response :success
          index = JSON.parse(response.parsed_body.dig('result', 'contents', 0, 'text'))

          assert_includes index['templates'], 'Artikel'
          assert_equal call_tool('get_schema', {})['templates'].sort, index['templates'].sort
        end

        # A mistyped parameter name must not act like "no filter": search_contents answered with the
        # total that way, and as an answer to a filtered question that is a massively inflated number.
        # The singular is the realistic case -- the plural is what sits in the schema.
        test 'an unknown argument is rejected instead of silently ignored' do
          jsonrpc_post('tools/call', { 'name' => 'search_contents', 'arguments' => { 'template_name' => 'Artikel' } }, token: @user.access_token)

          assert_response :success
          assert_predicate response.parsed_body.dig('result', 'isError'), :present?
          assert_includes response.parsed_body.dig('result', 'content', 0, 'text'), 'template_name'
        end

        # Counter-check to the test above: the correct name still filters.
        test 'the declared plural argument still filters' do
          result = call_tool('search_contents', { 'template_names' => ['Artikel'] })

          assert_equal ['Artikel'], result.dig('applied_filters', 'template_names')
        end

        # An attribute condition without in/not_in filters nothing -- previously the total came back
        # while applied_filters named the attribute.
        test 'an attribute condition without a comparison is rejected' do
          jsonrpc_post(
            'tools/call',
            { 'name' => 'search_contents', 'arguments' => { 'attributes' => [{ 'attribute' => 'bookable' }] } },
            token: @user.access_token
          )

          assert_response :success
          assert_predicate response.parsed_body.dig('result', 'isError'), :present?
        end

        # On a scoped find, the message ActiveRecord phrases contains the WHERE condition including
        # the template whitelist. At the same place the REST API answers only with "not found".
        #
        # What is expected is the TRANSLATED text in the mount's language, not the English literal:
        # since the locale pass-through in Tools::Base the error message follows the same language as
        # the tool descriptions. A literal here would have bound the check to the instance's default
        # language -- and the core of the test is that the query does NOT get through anyway.
        test 'a content id that does not exist does not leak the query behind it' do
          jsonrpc_post('tools/call', { 'name' => 'get_content', 'arguments' => { 'id' => SecureRandom.uuid } }, token: @user.access_token)

          assert_response :success
          text = response.parsed_body.dig('result', 'content', 0, 'text')

          assert_includes text, I18n.t('exceptions.active_record/record_not_found', locale: I18n.default_locale)
          assert_not_includes text, 'WHERE'
          assert_not_includes text, 'template_name'
        end

        # list_facets is the discovery for facet_values, which demands the tree under the name
        # classification_tree_label_id (from the OpenAPI route). Both keys name the same identifier --
        # previously it was called merely "id" in the response.
        test 'list_facets names the id the way facet_values asks for it' do
          scheme = call_tool('list_facets', {})['schemes'].first

          assert_equal scheme['id'], scheme['classification_tree_label_id']
          assert_predicate call_tool('facet_values', { 'classification_tree_label_id' => scheme['classification_tree_label_id'] })['values'], :present?
        end

        # On the global mount there is no endpoint describe_endpoint could describe -- the result
        # space is the user's api visibility scope. It therefore gets no invented name but
        # scope: 'global': a name would be indistinguishable from that of a real endpoint, and a
        # client would report it as the source of its numbers.
        test 'describe_endpoint profiles the instance-wide result space as a scope, not as an endpoint' do
          result = call_tool('describe_endpoint', {})

          assert_equal 'global', result.dig('endpoint', 'scope')
          assert_nil result.dig('endpoint', 'name')
          assert result.dig('endpoint', 'queryable_here')
          assert_equal call_tool('list_templates', {})['templates'], result['templates']
          assert_equal DataCycleCore::Mcp::Servers::GlobalServer::TOOLS.map(&:tool_name), result['tools'].pluck('tool')
        end

        # With an endpoint_id the same mount answers the question that follows list_endpoints ("which
        # endpoint suits my question"), which deliberately measures no content volumes.
        # queryable_here is false there: search_contents and friends keep running instance-wide here,
        # not over the described endpoint -- without that flag a client would subsequently report
        # numbers from the wrong one.
        test 'describe_endpoint profiles a single endpoint by id, but marks it as not queryable here' do
          result = call_tool('describe_endpoint', { 'endpoint_id' => @endpoint.id })

          assert_equal @endpoint.id, result.dig('endpoint', 'id')
          assert_not result.dig('endpoint', 'queryable_here')
          assert_equal ['Artikel'], result['templates'].pluck('template_name')
        end

        private

        def call_tool(name, arguments)
          call_tool_raw(name, arguments).dig('result', 'structuredContent', 'data')
        end

        def call_tool_raw(name, arguments)
          jsonrpc_post('tools/call', { 'name' => name, 'arguments' => arguments }, token: @user.access_token)

          assert_response :success
          response.parsed_body
        end
      end
    end
  end
end
