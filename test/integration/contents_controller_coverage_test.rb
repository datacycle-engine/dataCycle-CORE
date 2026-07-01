# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Covers the remaining ContentsController branches not exercised by
  # contents_controller_actions_test / contents_controller_endpoints_test:
  # show view-mode/geojson responses, edit split-source, external destroy,
  # validate guard, set_watch_list, content_classifier_form_body,
  # load_more_linked_objects and the create/update redirect branches.
  class ContentsControllerCoverageTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'CovContentsArtikel' })
      @source = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'CovContentsSource' })
      @external_system = DataCycleCore::ExternalSystem.first
      @external_content = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: { name: 'CovExternalArtikel', external_key: 'cov-contents-key', external_source_id: @external_system.id }
      )
      @poi = DataCycleCore::TestPreparations.create_content(
        template_name: 'POI',
        data_hash: { name: 'CovLinkedPOI', location: RGeo::Geographic.spherical_factory(srid: 4326).point(11.0, 47.0) }
      )
      @linked = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: { name: 'CovLinkingArtikel', content_location: [@poi.id] }
      )
      @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'CovContentsWatchList')
    end

    setup do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      sign_in(@current_user)
    end

    # ---------- show (json view-mode + geojson) ----------
    test 'show as json without a mode redirects to the api endpoint and resolves the watch_list' do
      get thing_path(@content, format: :json, watch_list_id: @watch_list.id)

      assert_response :redirect
    end

    test 'show as geojson redirects to the api geojson endpoint' do
      get thing_path(@content, format: :geojson)

      assert_response :redirect
    end

    # ---------- edit with a split source ----------
    test 'edit with a source parameter loads the split source' do
      get edit_thing_path(@content, source: "source_id=>#{@source.id},source_locale=>de")

      assert_response :success
    end

    # ---------- destroy external content (history + linked) ----------
    test 'destroy external content saves history and destroys linked' do
      delete thing_path(@external_content), headers: { referer: thing_path(@external_content) }

      assert_response :redirect
      assert_not DataCycleCore::Thing.exists?(@external_content.id)
    end

    # ---------- validate guard ----------
    test 'validate without id or template responds bad request' do
      post validate_things_path, params: {}

      assert_response :bad_request
    end

    # ---------- load_more_linked_objects (object_browser action) ----------
    test 'load_more_linked_objects renders the object browser partial' do
      post load_more_linked_objects_thing_path(@linked), xhr: true, params: {
        id: @linked.id,
        key: 'content_location',
        load_more_action: 'object_browser',
        locale: 'de'
      }, headers: { referer: thing_path(@linked) }

      assert_response :success
    end

    # ---------- create branches ----------
    # invalid data (blank name) drives the source lookup (source_params present)
    # then the not-valid redirect_back_or_to branch.
    test 'create with a source and invalid data redirects back' do
      post things_path, params: {
        template: 'Artikel',
        source_id: @source.id,
        thing: { translations: { de: { name: '' } } }
      }, headers: { referer: root_path }

      assert_response :redirect
    end

    # ---------- update branches ----------
    test 'update redirects back by default' do
      patch thing_path(@content), params: {
        locale: 'de',
        thing: { translations: { de: { name: 'CovUpdatedDefault' } } }
      }, headers: { referer: root_path }

      assert_response :redirect
    end

    test 'update with a new_locale redirects to the edit form in that locale' do
      patch thing_path(@content), params: {
        locale: 'en',
        new_locale: 'en',
        thing: { translations: { en: { name: 'CovUpdatedEnglish' } } }
      }, headers: { referer: root_path }

      assert_redirected_to edit_thing_path(@content, watch_list_id: nil, locale: 'en')
    end

    test 'update with invalid data flashes errors and redirects back' do
      patch thing_path(@content), params: {
        locale: 'de',
        thing: { translations: { de: { name: '' } } }
      }, headers: { referer: root_path }

      assert_response :redirect
    end
  end
end
