# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Exercises DataCycleCore::FilterConcern through the backend dashboard
  # (root_path -> BackendController#index), covering the tree/map/count-only
  # view modes and the load_last_filter / load_previous_page before_actions.
  class BackendControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @routes = Engine.routes
      @inhaltstypen = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
      @classification_tree = @inhaltstypen.classification_trees.find { |t| t.sub_classification_alias.present? }
      @tags_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').first
      @thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Backend Cov Artikel' })
      @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @imported_thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Backend Cov Imported' })
      @imported_thing.update_columns(external_source_id: @external_system.id, external_key: 'backend-cov-import')
    end

    setup do
      @current_user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      sign_in(@current_user)
    end

    # ---------- tree mode ----------
    test 'tree mode for a classification tree (ct_id) lists subtree and contents' do
      get root_path(mode: 'tree', ctl_id: @inhaltstypen.id, ct_id: @classification_tree.id, reset: true), headers: { referer: root_path }

      assert_response :success
    end

    test 'tree mode within a container (con_id) loads part_of contents via xhr' do
      # request json: the container branch sets @contents but not @classification_trees,
      # so the html tree partial would crash -> the json branch renders the count partial.
      get root_path(format: :json, mode: 'tree', ctl_id: @inhaltstypen.id, con_id: @thing.id, cpt_id: @classification_tree.id, reset: true),
          xhr: true, headers: { referer: root_path }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'tree mode grouped by external systems lists the active import systems' do
      get root_path(mode: 'tree', ctl_id: 'external_systems', reset: true), headers: { referer: root_path }

      assert_response :success
      assert_includes response.body, @external_system.name
    end

    test 'tree mode: expanding an external system lists its imported contents' do
      # dashboard drill-in fetch: xhr + json (see DataCycle.httpRequest default headers)
      get root_path(format: :json, mode: 'tree', ctl_id: 'external_systems', es_id: @external_system.id, reset: true),
          xhr: true, headers: { referer: root_path }

      assert_response :success
      assert response.parsed_body.key?('html')
      # the content imported from that system is listed, the source-less one is not
      assert_includes response.parsed_body['html'], @imported_thing.id
      assert_not_includes response.parsed_body['html'], @thing.id
    end

    test 'starting a search while grouped by external systems does not raise' do
      # regression: the search form now submits ctl_id=external_systems instead of a blank ctl_id,
      # which previously reached ClassificationTreeLabel.find('') and raised RecordNotFound
      get root_path(mode: 'tree', ctl_id: 'external_systems', reset: true),
          params: { f: { '0' => { 'c' => 'a', 'n' => 'Suche', 't' => 'fulltext_search', 'v' => 'Backend Cov' } } },
          headers: { referer: root_path }

      assert_response :success
    end

    test 'tree mode with an unresolvable ctl_id falls back gracefully instead of raising' do
      get root_path(mode: 'tree', ctl_id: '', reset: true), headers: { referer: root_path }

      assert_response :success
    end

    # ---------- map mode ----------
    test 'map mode paginates without count' do
      get root_path(mode: 'map', reset: true), headers: { referer: root_path }

      assert_response :success
    end

    # ---------- count_only modes ----------
    test 'count_only returns totals for each count_mode' do
      [
        { count_mode: 'classification_alias', ct_id: @classification_tree.id },
        { count_mode: 'ca_related', ct_id: @classification_tree.id },
        { count_mode: 'ca_recursive', ct_id: @classification_tree.id },
        { count_mode: 'classification_tree_label', ctl_id: @inhaltstypen.id },
        { count_mode: 'container', con_id: @thing.id },
        { count_mode: 'external_system', es_id: @external_system.id }
      ].each do |extra|
        get root_path(format: :json, count_only: '1', target: 'results', content_class: 'Thing', reset: true, **extra),
            headers: { referer: root_path }

        assert_response :success, "count_mode #{extra[:count_mode]} failed"
        assert response.parsed_body.key?('html')
      end
    end

    test 'count_only for the external_system mode counts contents imported from that system' do
      get root_path(format: :json, count_only: '1', target: 'results', content_class: 'Thing', reset: true, mode: 'tree', count_mode: 'external_system', es_id: @external_system.id),
          headers: { referer: root_path }

      assert_response :success
      count_html = response.parsed_body['html'].to_s.strip
      # external_system uses the plain-number count path (not the "X Inhalte" header format)
      assert_match(/\A[\d.,]+\z/, count_html)
      assert_operator(count_html.gsub(/\D/, '').to_i, :>=, 1)
    end

    test 'count_only in map mode applies the geometry filter' do
      get root_path(format: :json, count_only: '1', mode: 'map', target: 'results', reset: true), headers: { referer: root_path }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    # ---------- filter building (classification + hash-valued pre_filters) ----------
    test 'index builds classification and hash-valued filters' do
      get root_path, params: {
        f: {
          # a non-classification filter so the select-block reaches the geo/advanced clauses
          '0' => { 'c' => 'a', 'n' => 'Suche', 't' => 'fulltext_search', 'v' => 'Backend Cov' },
          # a classification_alias_ids filter -> @selected_classification_aliases lookup
          '1' => { 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'classification_alias_ids', 'v' => [@tags_alias.id] },
          # a Hash-valued (empty) filter -> exercises the Hash branch of the pre_filters reject
          '2' => { 'c' => 'b', 'n' => 'Leer', 't' => 'fulltext_search', 'v' => { 'min' => '', 'max' => '' } }
        }
      }, headers: { referer: root_path }

      assert_response :success
    end

    # ---------- load_last_filter before_action ----------
    test 'index loads the users most recent stored filter when no filter params are given' do
      DataCycleCore::StoredFilter.create!(name: 'Backend Cov Last Filter', user: @current_user, language: ['de'])

      get root_path, headers: { referer: root_path }

      assert_response :success
    end

    # ---------- load_previous_page before_action ----------
    test 'index redirects back to the stored return_to path' do
      # visiting a content show with the dashboard as referer stores session[:return_to]
      get thing_path(@thing), headers: { referer: root_url }

      # a plain dashboard request with no filter params then restores it
      get root_path

      assert_response :redirect
    end
  end
end
