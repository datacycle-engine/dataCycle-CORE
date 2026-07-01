# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Covers the utility endpoints on ApplicationController that are routed directly
  # to controller: :application (clear_all_caches, add_filter, add_tag_group) plus
  # the remote_render missing-parameter branch.
  class ApplicationControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    setup do
      sign_in(DataCycleCore::User.find_by(email: 'admin@datacycle.at'))
    end

    # ---------- clear_all_caches ----------
    test 'clear_all_caches redirects back for an html request' do
      delete clear_all_caches_path, headers: { referer: root_path }

      assert_response :redirect
    end

    test 'clear_all_caches renders a turbo stream' do
      delete clear_all_caches_path, headers: { referer: root_path, 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_equal 'text/vnd.turbo-stream.html', response.media_type
    end

    # ---------- add_filter ----------
    test 'add_filter returns an identifier and rendered html' do
      post add_filter_path, params: { n: 'Suchbegriff', t: 'fulltext_search', m: 'i', q: 'like' }

      assert_response :success
      body = response.parsed_body

      assert body.key?('identifier')
      assert body.key?('html')
    end

    # ---------- add_tag_group ----------
    test 'add_tag_group builds options from an f filter hash' do
      post add_tag_group_path, params: {
        f: { 'tag-group-1' => { 'n' => 'Tags', 't' => 'classification_alias_ids', 'v' => [] } }
      }

      assert_response :success
      assert response.parsed_body.key?('identifier')
    end

    test 'add_tag_group builds options from a direct key' do
      post add_tag_group_path, params: { roles: ['role-1'] }

      assert_response :success
      assert response.parsed_body.key?('identifier')
    end

    # ---------- remote_render (missing parameter branch) ----------
    test 'remote_render without a partial or render_function responds bad request as json' do
      get remote_render_path(format: :json)

      assert_response :bad_request
      assert response.parsed_body.key?('error')
    end

    test 'remote_render without a partial or render_function responds bad request as html' do
      get remote_render_path

      assert_response :bad_request
    end
  end
end
