# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V4
      class DuplicatesTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          # admin role: holds merge_duplicates
          @privileged_user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
          # guest role: holds no merge_duplicates. confirmed_at is required, devise would otherwise
          # bounce the sign_in with a redirect instead of letting the ability check answer
          @restricted_user = DataCycleCore::User.find_or_create_by!(email: 'duplicates-guest@example.com') do |u|
            u.password = SecureRandom.hex
            u.confirmed_at = 1.day.ago
            u.role = DataCycleCore::Role.find_by(rank: 0)
          end
        end

        setup do
          @previous_user_filters = DataCycleCore.user_filters.deep_dup
          @content = create_content('Artikel', { name: "Duplicates Original #{SecureRandom.hex(6)}" })
          @duplicate = create_content('Artikel', { name: "Duplicates Candidate #{SecureRandom.hex(6)}" })
          sign_in(@privileged_user)
        end

        teardown do
          DataCycleCore.user_filters = @previous_user_filters
        end

        def mark_pair(original, duplicate, method: 'only_title', score: 83, false_positive: false)
          DataCycleCore::ThingDuplicate.create!(thing_id: original.id, thing_duplicate_id: duplicate.id, method:, score:, false_positive:)
        end

        # Installs a forced api scope user_filter for the privileged user's role, built from raw filter
        # parameters (a hash carrying 't' is taken over verbatim by
        # Type::StoredFilter::Parameters.param_from_definition).
        def force_api_scope(*parameters)
          DataCycleCore.user_filters = {
            tmp_api_scope: {
              'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => [@privileged_user.role_name] }],
              'force' => true,
              'scope' => ['api'],
              'stored_filter' => parameters
            }
          }
        end

        def scope_to_content(content)
          force_api_scope({ 't' => 'id', 'v' => { 'text' => content.id }, 'q' => 'internal', 'n' => 'id' })
        end

        # A persisted collection restricting to Artikel that are currently valid - the shape a project
        # uses when its api scope is a stored filter rather than flat parameters.
        def valid_artikel_filter
          DataCycleCore::StoredFilter.create!(
            name: "Api Scope #{SecureRandom.hex(4)}",
            user_id: @privileged_user.id,
            language: ['de'],
            parameters: [
              { 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } },
              { 't' => 'in_validity_period', 'v' => nil, 'n' => 'validity' }
            ]
          )
        end

        def expire(content)
          DataCycleCore::Thing.where(id: content.id).update_all("validity_range = tstzrange(now() - interval '2 days', now() - interval '1 day')")
        end

        def duplicate_entries
          response.parsed_body['dc:duplicates'] || []
        end

        # ---- index ----

        test 'GET duplicates returns the candidates with score and method' do
          mark_pair(@content, @duplicate, method: 'only_title', score: 83)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_equal @content.id, response.parsed_body['@id']
          assert_equal 1, duplicate_entries.size

          entry = duplicate_entries.first

          assert_equal @duplicate.id, entry['@id']
          assert_in_delta(83.0, entry['dc:score'])
          assert_equal ['only_title'], entry['dc:duplicateMethod']
          assert_not entry['dc:falsePositive']
          assert_predicate entry['name'], :present?
        end

        test 'GET duplicates groups the methods of one pair into a single entry' do
          mark_pair(@content, @duplicate, method: 'only_title', score: 83)
          mark_pair(@content, @duplicate, method: 'name_similarity', score: 91)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_equal 1, duplicate_entries.size

          entry = duplicate_entries.first

          assert_in_delta(91.0, entry['dc:score'])
          assert_equal ['name_similarity', 'only_title'], entry['dc:duplicateMethod']
        end

        test 'GET duplicates is sorted by score descending' do
          weaker = create_content('Artikel', { name: "Duplicates Weak #{SecureRandom.hex(6)}" })
          mark_pair(@content, @duplicate, score: 90)
          mark_pair(@content, weaker, score: 40)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_equal [@duplicate.id, weaker.id], duplicate_entries.pluck('@id')
        end

        test 'GET duplicates excludes false positives by default and returns them on demand' do
          mark_pair(@content, @duplicate, false_positive: true)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_empty duplicate_entries

          get api_v4_thing_duplicates_path(id: @content.id, falsePositive: true)

          assert_response :ok
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
          assert duplicate_entries.first['dc:falsePositive']
        end

        test 'GET duplicates reads falsePositive the way the contract validates it' do
          mark_pair(@content, @duplicate, false_positive: true)

          # same trap as filter[duplicateCandidates][exists]: 'no' validates as false, so it has to
          # answer with the active pairs, not with the dismissed ones
          ['no', 'n', 'off', '0'].each do |falsy|
            get api_v4_thing_duplicates_path(id: @content.id, falsePositive: falsy)

            assert_response :ok
            assert_empty duplicate_entries, "falsePositive=#{falsy}"
          end

          ['yes', 'y', 'on', '1'].each do |truthy|
            get api_v4_thing_duplicates_path(id: @content.id, falsePositive: truthy)

            assert_response :ok
            assert_equal [@duplicate.id], duplicate_entries.pluck('@id'), "falsePositive=#{truthy}"
          end
        end

        test 'GET duplicates supports paging' do
          second = create_content('Artikel', { name: "Duplicates Second #{SecureRandom.hex(6)}" })
          mark_pair(@content, @duplicate, score: 90)
          mark_pair(@content, second, score: 40)

          get api_v4_thing_duplicates_path(id: @content.id, page: { size: 1, number: 2 })

          assert_response :ok
          assert_equal [second.id], duplicate_entries.pluck('@id')
          assert_equal 2, response.parsed_body.dig('meta', 'total')
          assert_equal 2, response.parsed_body.dig('meta', 'pages')
        end

        test 'GET duplicates supports page[limit] and page[offset]' do
          second = create_content('Artikel', { name: "Duplicates Second #{SecureRandom.hex(6)}" })
          mark_pair(@content, @duplicate, score: 90)
          mark_pair(@content, second, score: 40)

          get api_v4_thing_duplicates_path(id: @content.id, page: { limit: 1, offset: 1 })

          assert_response :ok
          assert_equal [second.id], duplicate_entries.pluck('@id')
          assert_equal 2, response.parsed_body.dig('meta', 'total')
        end

        test 'GET duplicates applies page[offset] on top of page[size] and page[number]' do
          second = create_content('Artikel', { name: "Duplicates Second #{SecureRandom.hex(6)}" })
          mark_pair(@content, @duplicate, score: 90)
          mark_pair(@content, second, score: 40)

          # ApiBaseController#apply_paging hands page[offset] to kaminari as padding in the
          # size/number branch too, so it must not be dropped without page[limit]
          get api_v4_thing_duplicates_path(id: @content.id, page: { size: 1, offset: 1 })

          assert_response :ok
          assert_equal [second.id], duplicate_entries.pluck('@id')
        end

        test 'GET duplicates omits meta for section[meta]=0' do
          mark_pair(@content, @duplicate, score: 90)

          get api_v4_thing_duplicates_path(id: @content.id, section: { meta: 0 })

          assert_response :ok
          assert_not response.parsed_body.key?('meta')
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
        end

        test 'GET duplicates pages equal scores without dropping or repeating an entry' do
          second = create_content('Artikel', { name: "Duplicates Second #{SecureRandom.hex(6)}" })
          mark_pair(@content, @duplicate, score: 70)
          mark_pair(@content, second, score: 70)

          paged = [1, 2].flat_map do |number|
            get api_v4_thing_duplicates_path(id: @content.id, page: { size: 1, number: })

            assert_response :ok
            duplicate_entries.pluck('@id')
          end

          assert_equal [@duplicate.id, second.id].sort, paged.sort
        end

        test 'GET duplicates is not found when the feature is disabled' do
          DataCycleCore::Feature::DuplicateCandidate.stub(:enabled?, false) do
            get api_v4_thing_duplicates_path(id: @content.id)

            assert_response :not_found
          end
        end

        test 'GET duplicates without the ability is unauthorized' do
          sign_in(@restricted_user)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :unauthorized
        end

        test 'GET duplicates without a signed in user is unauthorized' do
          # answered by the warden authenticate block the whole api namespace sits in (routes.rb), before
          # any controller code runs - the endpoints need no guard of their own for it
          sign_out(@privileged_user)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :unauthorized
        end

        # ---- api scope ----

        test 'GET duplicates for a content outside the api scope is unauthorized' do
          mark_pair(@content, @duplicate, score: 90)
          scope_to_content(@duplicate)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :unauthorized
        end

        test 'GET duplicates hides candidates outside the api scope' do
          mark_pair(@content, @duplicate, score: 90)
          scope_to_content(@content)

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_empty duplicate_entries
          assert_equal 0, response.parsed_body.dig('meta', 'total')
        end

        test 'POST duplicates with a duplicate outside the api scope is unauthorized' do
          scope_to_content(@content)

          # @id is freely chosen by the caller, so without the scope check the endpoint would both
          # report the title of any content of the same template and attach a manual pair to it
          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :unauthorized
          assert_empty DataCycleCore::ThingDuplicate.where(thing_id: @content.id, thing_duplicate_id: @duplicate.id)
        end

        test 'POST merge with a duplicate outside the api scope is unauthorized' do
          mark_pair(@content, @duplicate, score: 90)
          scope_to_content(@content)

          post api_v4_merge_thing_duplicates_path(id: @content.id, duplicate_id: @duplicate.id)

          assert_response :unauthorized
        end

        test 'GET duplicates keeps expired candidates visible inside the api scope' do
          out_of_scope = create_content('Bild', { name: "Duplicates Image #{SecureRandom.hex(6)}" })
          mark_pair(@content, @duplicate, score: 90)
          mark_pair(@content, out_of_scope, score: 95)
          expire(@duplicate)

          # the validity part of the api scope filter is bypassed on purpose - a duplicate review tool
          # has to see expired contents - while the access scope itself still applies
          force_api_scope(
            { 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } },
            { 't' => 'in_validity_period', 'v' => nil, 'n' => 'validity' }
          )

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
        end

        test 'GET duplicates keeps expired candidates visible when the api scope is a stored filter' do
          out_of_scope = create_content('Bild', { name: "Duplicates Image #{SecureRandom.hex(6)}" })
          mark_pair(@content, @duplicate, score: 90)
          mark_pair(@content, out_of_scope, score: 95)
          expire(@duplicate)

          # filter_ids resolves a StoredFilter of its own, so the validity parameters inside it are never
          # part of the parameter list of the scope filter itself
          force_api_scope({ 't' => 'filter_ids', 'v' => [valid_artikel_filter.id], 'n' => 'scope' })

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
        end

        test 'GET duplicates for an expired content inside a stored filter api scope is authorized' do
          mark_pair(@content, @duplicate, score: 90)
          expire(@content)
          force_api_scope({ 't' => 'filter_ids', 'v' => [valid_artikel_filter.id], 'n' => 'scope' })

          # the content of the route must stay reachable as well, otherwise the review tool cannot open
          # an expired content at all
          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
        end

        test 'GET duplicates keeps expired candidates visible when the api scope uses a union' do
          mark_pair(@content, @duplicate, score: 90)
          expire(@duplicate)

          # apply_union_filter! builds a fresh StoredFilter per branch, which never sees a stripped
          # parameter list either
          force_api_scope(
            { 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } },
            { 't' => 'union', 'v' => [{ 't' => 'in_validity_period', 'v' => nil, 'n' => 'validity' }], 'n' => 'union' }
          )

          get api_v4_thing_duplicates_path(id: @content.id)

          assert_response :ok
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
        end

        test 'duplicates for an embedded content are unprocessable, with and without an api scope' do
          @duplicate.update_column(:content_type, 'embedded')

          # an embedded content can never have duplicates (detection skips them), so it is rejected
          # before the api scope is consulted - which excludes embedded contents and would otherwise
          # answer with 401 for a scoped caller and 422 for an unscoped one
          scopes = {
            'without an api scope' => -> { DataCycleCore.user_filters = {} },
            'with an api scope' => -> { force_api_scope({ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } }) }
          }

          scopes.each do |shape, install_scope|
            install_scope.call

            post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

            assert_response :unprocessable_content, "#{shape}: POST answered #{response.status}"
            assert_empty @content.duplicate_candidates.reload

            get api_v4_thing_duplicates_path(id: @duplicate.id)

            assert_response :unprocessable_content, "#{shape}: GET answered #{response.status}"
          end
        end

        # ---- create ----

        test 'POST duplicates marks a pair manually' do
          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :created
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
          assert_equal ['manual'], duplicate_entries.first['dc:duplicateMethod']
          assert_in_delta(100.0, duplicate_entries.first['dc:score'])
        end

        test 'POST duplicates is idempotent' do
          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :created

          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :ok
          assert_equal 1, DataCycleCore::ThingDuplicate.where(method: 'manual').where(thing_id: [@content.id, @duplicate.id]).count
        end

        test 'POST duplicates keeps the automatic candidates of the same pair' do
          mark_pair(@content, @duplicate, method: 'only_title', score: 83)

          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :created
          assert_equal ['manual', 'only_title'], duplicate_entries.first['dc:duplicateMethod']
        end

        test 'POST duplicates reactivates a dismissed pair' do
          mark_pair(@content, @duplicate, method: 'only_title', score: 83, false_positive: true)

          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :created
          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
          # dismissing marks every row of the pair, so reactivating clears every row again
          assert_equal ['manual', 'only_title'], duplicate_entries.first['dc:duplicateMethod']
        end

        test 'POST duplicates for a different template is unprocessable' do
          other_template = create_content('Bild', { name: "Duplicates Image #{SecureRandom.hex(6)}" })

          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': other_template.id }

          assert_response :unprocessable_content
          assert_empty @content.duplicate_candidates.reload
        end

        test 'POST duplicates for the content itself is unprocessable' do
          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @content.id }

          assert_response :unprocessable_content
          assert_empty @content.duplicate_candidates.reload
        end

        test 'POST duplicates for an embedded content is unprocessable' do
          # embedded? reads the content_type column, so the branch is reachable without an embedded template
          @duplicate.update_column(:content_type, 'embedded')

          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :unprocessable_content
          assert_empty @content.duplicate_candidates.reload
        end

        test 'POST duplicates without an id is a bad request' do
          post api_v4_thing_duplicates_path(id: @content.id), params: {}

          assert_response :bad_request
        end

        test 'POST duplicates with an unknown id is not found' do
          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': SecureRandom.uuid }

          assert_response :not_found
        end

        test 'POST duplicates without the ability is unauthorized' do
          sign_in(@restricted_user)

          post api_v4_thing_duplicates_path(id: @content.id), params: { '@id': @duplicate.id }

          assert_response :unauthorized
          assert_empty @content.duplicate_candidates.reload
        end

        # ---- merge ----

        test 'POST merge accepts the merge and removes the pair' do
          mark_pair(@content, @duplicate)

          post api_v4_merge_thing_duplicates_path(id: @content.id, duplicate_id: @duplicate.id)

          assert_response :accepted
          assert_empty @content.duplicate_candidates.reload
        end

        test 'POST merge for a different template is unprocessable' do
          other_template = create_content('Bild', { name: "Duplicates Image #{SecureRandom.hex(6)}" })

          post api_v4_merge_thing_duplicates_path(id: @content.id, duplicate_id: other_template.id)

          assert_response :unprocessable_content
          assert_predicate DataCycleCore::Thing.find_by(id: other_template.id), :present?
        end

        test 'POST merge with itself is unprocessable' do
          post api_v4_merge_thing_duplicates_path(id: @content.id, duplicate_id: @content.id)

          assert_response :unprocessable_content
        end

        test 'POST merge without the ability is unauthorized' do
          mark_pair(@content, @duplicate)
          sign_in(@restricted_user)

          post api_v4_merge_thing_duplicates_path(id: @content.id, duplicate_id: @duplicate.id)

          assert_response :unauthorized
          assert_predicate @content.duplicate_candidates.reload, :present?
        end

        # ---- false_positive ----

        test 'POST false_positive dismisses the pair' do
          mark_pair(@content, @duplicate)

          post api_v4_false_positive_thing_duplicates_path(id: @content.id, duplicate_id: @duplicate.id)

          assert_response :ok
          assert_empty duplicate_entries

          get api_v4_thing_duplicates_path(id: @content.id, falsePositive: true)

          assert_equal [@duplicate.id], duplicate_entries.pluck('@id')
        end

        test 'POST false_positive without the ability is unauthorized' do
          mark_pair(@content, @duplicate)
          sign_in(@restricted_user)

          post api_v4_false_positive_thing_duplicates_path(id: @content.id, duplicate_id: @duplicate.id)

          assert_response :unauthorized
          assert_predicate @content.duplicate_candidates.reload, :present?
        end

        # ---- language ----

        test 'GET duplicates renders the name in the requested language' do
          english_only = I18n.with_locale(:en) { create_content('Artikel', { name: "Duplicates English #{SecureRandom.hex(6)}" }) }
          mark_pair(@content, english_only, score: 90)

          # the locale is resolved per duplicate, otherwise the title is looked up in the default
          # locale and comes back empty for a content that is not translated there
          get api_v4_thing_duplicates_path(id: @content.id, language: 'en')

          assert_response :ok
          assert_equal I18n.with_locale(:en) { english_only.title }, duplicate_entries.first['name']
        end

        test 'a thing response never carries duplicate candidates' do
          mark_pair(@content, @duplicate)

          # duplicates are deliberately only available through the dedicated endpoint, so neither a
          # named include nor a broad one may add them to a content response
          ['dc:duplicates', 'full,recursive'].each do |include_parameter|
            get api_v4_thing_path(id: @content.id, include: include_parameter)

            assert_response :ok
            assert_not response.parsed_body['@graph'].first.key?('dc:duplicates'), "include=#{include_parameter} leaked the candidates"
          end
        end

        # ---- filter[duplicateCandidates] ----

        def filtered_ids(duplicate_filter)
          get api_v4_things_path(filter: { contentId: { in: [[@content.id, @duplicate.id].join(',')] }, duplicateCandidates: duplicate_filter })

          assert_response :ok
          response.parsed_body['@graph'].pluck('@id')
        end

        test 'filter[duplicateCandidates][exists] restricts the result set' do
          mark_pair(@content, @duplicate, score: 90)
          without_candidates = create_content('Artikel', { name: "Duplicates None #{SecureRandom.hex(6)}" })

          assert_equal [@content.id, @duplicate.id].sort, filtered_ids({ exists: true }).sort
          assert_empty filtered_ids({ exists: false })

          get api_v4_things_path(filter: { contentId: { in: [without_candidates.id] }, duplicateCandidates: { exists: false } })

          assert_equal [without_candidates.id], response.parsed_body['@graph'].pluck('@id')
        end

        test 'filter[duplicateCandidates][exists] accepts every boolean notation' do
          mark_pair(@content, @duplicate, score: 90)

          # every notation the contract accepts as a boolean has to be applied as the contract read it:
          # the filter method compares against the string 'true', so an own cast (or none) answered a
          # valid request with the opposite set - 'no' and 'n' validate as false but are unknown to
          # ActiveModel::Type::Boolean
          ['true', '1', 't', 'on', 'y', 'yes', 'Yes', 'TRUE'].each do |truthy|
            assert_equal [@content.id, @duplicate.id].sort, filtered_ids({ exists: truthy }).sort, "exists=#{truthy}"
          end

          ['false', '0', 'f', 'off', 'n', 'no', 'No', 'NO'].each do |falsy|
            assert_empty filtered_ids({ exists: falsy }), "exists=#{falsy}"
          end
        end

        test 'filter[duplicateCandidates] reads a fractional score bound as the contract does' do
          mark_pair(@content, @duplicate, score: 80)

          # the schema coerces the bounds to floats, so they arrive as numbers rather than as the
          # strings the filter method would have to convert itself
          assert_equal [@content.id, @duplicate.id].sort, filtered_ids({ minScore: '79.5' }).sort
          assert_empty filtered_ids({ minScore: '80.5' })
        end

        test 'filter[duplicateCandidates] restricts by score' do
          mark_pair(@content, @duplicate, score: 40)

          assert_empty filtered_ids({ minScore: 80 })
          assert_equal [@content.id, @duplicate.id].sort, filtered_ids({ minScore: 20 }).sort
          assert_empty filtered_ids({ maxScore: 20 })
        end

        test 'filter[duplicateCandidates] respects a fractional score bound' do
          mark_pair(@content, @duplicate, score: 80)

          assert_equal [@content.id, @duplicate.id].sort, filtered_ids({ minScore: 79.5 }).sort
          assert_empty filtered_ids({ minScore: 80.5 })
        end

        test 'filter[duplicateCandidates] restricts by method' do
          mark_pair(@content, @duplicate, method: 'only_title', score: 83)

          assert_equal [@content.id, @duplicate.id].sort, filtered_ids({ method: 'only_title' }).sort
          assert_empty filtered_ids({ method: 'manual' })
        end

        # ---- unknown thing ----

        test 'duplicates for an unknown thing is not found' do
          get api_v4_thing_duplicates_path(id: SecureRandom.uuid)

          assert_response :not_found
        end
      end
    end
  end
end
