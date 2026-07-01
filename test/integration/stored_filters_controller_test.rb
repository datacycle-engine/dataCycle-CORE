# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StoredFiltersControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    setup do
      @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @guest = DataCycleCore::User.find_by(email: 'guest@datacycle.at')
      sign_in(@admin)
      @filter = DataCycleCore::StoredFilter.create!(name: 'Cov Stored Filter', user: @admin, language: ['de'])
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
