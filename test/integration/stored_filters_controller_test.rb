# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StoredFiltersControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    setup do
      @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @guest = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
      # long-lived local test DBs can outlast the consent grace period, which would otherwise
      # redirect every HTML-format request in this file to the terms/privacy consent screen.
      @admin.update!(additional_attributes: (@admin.additional_attributes || {}).merge('terms_conditions_at' => Time.current, 'privacy_policy_at' => Time.current))
      sign_in(@admin)
      @filter = DataCycleCore::StoredFilter.create!(name: 'Cov Stored Filter', user: @admin, language: ['de'])
      @tags_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').first
    end

    # ---------- index ----------
    test 'index html' do
      get stored_filters_path

      assert_response :success
    end

    test 'index json renders the stored searches partial' do
      get stored_filters_path(format: :json), params: { page: 1, last_day: 'foo' }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    # ---------- saved_searches ----------
    test 'saved_searches html' do
      get saved_searches_stored_filters_path

      assert_response :success
    end

    test 'saved_searches json with a query' do
      get saved_searches_stored_filters_path(format: :json), params: { q: 'Cov', page: 1 }

      assert_response :success
      assert response.parsed_body.key?('html')
      assert response.parsed_body.key?('count')
    end

    test 'saved_searches json with load_all and a custom partial' do
      get saved_searches_stored_filters_path(format: :json), params: { load_all: '1', partial: 'saved_searches_list', page: 1 }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    # #43524: exact lookup for the classification "used in stored filters" feature, so a click
    # always lands on the precise stored filter(s) instead of relying on ambiguous name search.
    test 'saved_searches json with ids restricts the result to exactly those stored filters' do
      other = DataCycleCore::StoredFilter.create!(name: 'Cov Other Stored Filter', user: @admin, language: ['de'])

      get saved_searches_stored_filters_path(format: :json), params: { ids: [@filter.id], page: 1 }

      assert_response :success
      assert response.parsed_body.key?('html')
      assert_match @filter.name, response.parsed_body['html']
      assert_no_match other.name, response.parsed_body['html']
    end

    # #43524: the stored-filter-usage panel POSTs the ids as form fields instead of a GET query
    # string, which can exceed the URI length limit for a classification used by many searches.
    test 'saved_searches also accepts ids via POST' do
      other = DataCycleCore::StoredFilter.create!(name: 'Cov Other Stored Filter', user: @admin, language: ['de'])

      post saved_searches_stored_filters_path(format: :json), params: { ids: [@filter.id], page: 1 }

      assert_response :success
      assert response.parsed_body.key?('html')
      assert_match @filter.name, response.parsed_body['html']
      assert_no_match other.name, response.parsed_body['html']
    end

    # #43524: a full-text query must narrow within the ids restriction, not replace it - otherwise
    # typing in the search box while the classification-usage chip is active would silently show
    # unrelated stored filters again.
    test 'saved_searches json applies a full-text query within the ids restriction' do
      other = DataCycleCore::StoredFilter.create!(name: 'Cov Other Stored Filter', user: @admin, language: ['de'])

      get saved_searches_stored_filters_path(format: :json), params: { ids: [@filter.id], q: 'Cov', page: 1 }

      assert_response :success
      assert_match @filter.name, response.parsed_body['html']
      assert_no_match other.name, response.parsed_body['html']
    end

    # #43524: the single-item link from the classification "used in stored filters" panel sends both
    # `ids` (the actual restriction) and `q` set to the search's own exact name, so the search field
    # visibly explains the restriction instead of showing one unexplained result in an empty-looking
    # search box (see stored_filter_usage.html.erb).
    test 'saved_searches html prefills the search field with q and still shows the ids-restricted result' do
      get saved_searches_stored_filters_path, params: { ids: [@filter.id], q: @filter.name }

      assert_response :success
      assert_select('.fulltext-search-field[value=?]', @filter.name)
      assert_select('.content-list', text: /#{Regexp.escape(@filter.name)}/)
    end

    # #43524: the saved-searches page renders a removable chip naming the classification - the tree
    # label (e.g. "Tags") as the group label, the specific classification (e.g. "Tag 1") as the value
    # pill, mirroring how a classification filter tag looks in the search results - and exposes the
    # restricting ids as a data attribute so stored_filter.js can resend them on every subsequent
    # search/pagination request (see StoredFilter component).
    test 'saved_searches html with ids and a classification_id renders a removable classification-usage chip' do
      get saved_searches_stored_filters_path, params: { ids: [@filter.id], classification_id: @tags_alias.id }

      assert_response :success
      assert_select('.classification-usage-chip .tag-group-label', text: /Tags/)
      assert_select('.classification-usage-chip .tag', text: /#{Regexp.escape(@tags_alias.internal_name)}/)
      assert_select('.classification-usage-chip .remove-tag')
      assert_select('section.stored-searches-list[data-classification-usage-ids=?]', @filter.id)
    end

    test 'saved_searches html with ids and a classification_tree_label id shows the tree name as the group label and a generic "all" value' do
      tags_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')

      get saved_searches_stored_filters_path, params: { ids: [@filter.id], classification_id: tags_label.id }

      assert_response :success
      assert_select('.classification-usage-chip .tag-group-label', text: /Tags/)
      assert_select('.classification-usage-chip .tag', text: /#{Regexp.escape(I18n.t('data_cycle_core.stored_searches.classification_usage_all', locale: 'de'))}/)
    end

    test 'saved_searches html without ids does not render a classification-usage chip' do
      get saved_searches_stored_filters_path

      assert_response :success
      assert_select('.classification-usage-chip', count: 0)
    end

    # #43524: a single-item link from the classification "used in stored filters" panel also sets
    # `ids` (to land on that exact search unambiguously, see stored_filter_usage.html.erb), but that's
    # precise "open this one search" navigation, not a classification-restricted browse - so without a
    # `classification_id` there is no chip, and no sticky ids-resending data attribute either.
    test 'saved_searches html with ids but no classification_id renders no classification-usage chip' do
      get saved_searches_stored_filters_path, params: { ids: [@filter.id] }

      assert_response :success
      assert_select('.classification-usage-chip', count: 0)
      assert_select('section.stored-searches-list[data-classification-usage-ids=""]')
    end

    # ---------- show ----------
    test 'show redirects to root with the stored filter' do
      get stored_filter_path(@filter.id)

      assert_response :redirect
    end

    # ---------- create ----------
    test 'create a new stored filter and redirect' do
      assert_difference -> { @admin.stored_filters.where.not(name: nil).count }, 1 do
        post stored_filters_path, params: { stored_filter: { name: 'Cov New Filter' } }
      end

      assert_response :redirect
    end

    test 'create with an invalid cache_ttl redirects with an alert' do
      post stored_filters_path, params: { stored_filter: { name: 'Cov Invalid', cache_ttl: 99_999 } }

      assert_response :redirect
    end

    test 'create updates an existing stored filter by id' do
      post stored_filters_path, params: { stored_filter: { id: @filter.id, name: 'Cov Renamed' } }

      assert_response :redirect
      assert_equal 'Cov Renamed', @filter.reload.name
    end

    # updating a filter's parameters must persist ONLY the form-derived parameters, NOT the creator's user
    # filters: user filters are resolved per viewer at read time (see StoredFilter#user_filter_parameters)
    # and applied live, so a filter saved by a restricted user must not carry that restriction for everyone.
    test 'create with update_filter_parameters does not bake the creator user filters into the persisted parameters' do
      previous_user_filters = DataCycleCore.user_filters.deep_dup
      DataCycleCore.user_filters = { tmp_bake: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['all'] }], 'scope' => ['backend'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person'] } }] } }

      post stored_filters_path, params: { stored_filter: { id: @filter.id }, update_filter_parameters: true, f: { '0' => { 'c' => 'a', 'n' => 'Suche', 't' => 'fulltext_search', 'v' => 'Cov' } } }

      assert_response :redirect
      parameters = @filter.reload.parameters
      # the form-derived parameter is persisted ...
      assert(parameters.any? { |f| f['t'] == 'fulltext_search' }, 'the form filter should be persisted')
      # ... but the creator's user filter is not baked in.
      assert(parameters.none? { |f| f['c'].in?(['u', 'uf']) }, 'creator user filters must not be baked into the persisted parameters')
    ensure
      DataCycleCore.user_filters = previous_user_filters
    end

    # ---------- render_update_form ----------
    test 'render_update_form for a new filter' do
      get render_update_form_stored_filters_path(format: :json), params: { stored_filter: { name: 'Cov Form' } }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'render_update_form for an existing filter' do
      get render_update_form_stored_filters_path(format: :json), params: { stored_filter: { id: @filter.id } }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    # ---------- destroy ----------
    test 'destroy unnames a stored filter' do
      delete stored_filter_path(@filter.id)

      assert_response :redirect
      assert_nil @filter.reload.name
    end

    # ---------- search ----------
    test 'search lists accessible stored filters including other users filters' do
      DataCycleCore::StoredFilter.create!(name: 'Cov Guest Filter', user: @guest, language: ['de'])

      get search_stored_filters_path(format: :json), params: { q: 'Cov' }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    test 'search without a query' do
      get search_stored_filters_path(format: :json)

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    # ---------- select_search_or_collection ----------
    test 'select_search_or_collection lists matching collections' do
      get select_search_or_collection_stored_filters_path(format: :json), params: { q: 'Cov', max: '10' }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    # ---------- rebuild_cache ----------
    test 'rebuild_cache without caching enabled shows an error and redirects' do
      post rebuild_cache_stored_filter_path(@filter.id)

      assert_response :redirect
    end

    test 'rebuild_cache with caching enabled rebuilds via turbo_stream' do
      cached = DataCycleCore::StoredFilter.create!(name: 'Cov Cached', user: @admin, language: ['de'], cache_ttl: 60)

      post rebuild_cache_stored_filter_path(cached.id), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_equal 'text/vnd.turbo-stream.html', response.media_type
    end
  end
end
