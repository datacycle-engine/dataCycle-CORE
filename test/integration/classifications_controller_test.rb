# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationsControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    setup do
      @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      sign_in(@admin)
      @tags_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
      @tags_alias = DataCycleCore::ClassificationAlias.for_tree('Tags').first
      @tags_tree = DataCycleCore::ClassificationTree.find_by(classification_alias_id: @tags_alias.id)
    end

    # builds a standalone classification alias + classification + group + tree node,
    # mirroring ClassificationsController#create, for move/merge/download fixtures.
    def build_alias(tree_label, name, parent_alias: nil)
      ca = DataCycleCore::ClassificationAlias.new
      I18n.available_locales.each { |l| I18n.with_locale(l) { ca.name = name } }
      ca.save!
      classification = DataCycleCore::Classification.create!(name: ca.internal_name)
      DataCycleCore::ClassificationGroup.create!(classification:, classification_alias: ca)
      DataCycleCore::ClassificationTree.create!(
        classification_tree_label: tree_label,
        parent_classification_alias: parent_alias,
        sub_classification_alias: ca
      )
      ca.reload
    end

    # ---------- index (json) ----------
    test 'index json by classification_tree_label_id' do
      get classifications_path(format: :json), params: { classification_tree_label_id: @tags_label.id }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'index json by classification_tree_id' do
      get classifications_path(format: :json), params: { classification_tree_id: @tags_tree.id }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'index json by mapped_classification_alias_id' do
      get classifications_path(format: :json), params: { classification_tree_label_id: @tags_label.id, mapped_classification_alias_id: @tags_alias.id }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'index json without identifying param raises' do
      assert_raises(RuntimeError) do
        get classifications_path(format: :json)
      end
    end

    # ---------- search ----------
    test 'search within Inhaltstypen excludes the filter classifications' do
      get search_classifications_path(format: :json), params: { tree_label: 'Inhaltstypen' }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    test 'search within a tree label with a query and all option flags' do
      get search_classifications_path(format: :json), params: {
        tree_label: 'Tags',
        q: 'Tag',
        max: '10',
        exclude: [@tags_alias.id],
        exclude_tree_label: DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')&.id,
        with_geometry: 'false',
        preload: ['classification_tree'],
        'disabled_unless_any?' => 'classification_polygons'
      }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    test 'search across all classifications with geometry filter' do
      get search_classifications_path(format: :json), params: { with_geometry: 'true', max: '5' }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    # ---------- find ----------
    test 'find by classification ids within a tree label' do
      get find_classifications_path(format: :json), params: {
        ids: [@tags_alias.primary_classification.id],
        tree_label: 'Tags'
      }

      assert_response :success
      body = response.parsed_body

      assert_kind_of Array, body
      assert(body.any? { |c| c['classification_alias_id'] == @tags_alias.id })
    end

    # ---------- create ----------
    test 'create a classification tree label' do
      assert_difference -> { DataCycleCore::ClassificationTreeLabel.count } => 1 do
        post classifications_path, xhr: true, params: {
          classification_tree_label: { name: 'COV LABEL', visibility: ['show', 'edit'] }
        }
      end

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'create a root classification alias under a tree label' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV CREATE ROOT', visibility: ['classification_administration'])

      assert_difference -> { DataCycleCore::ClassificationAlias.count } => 1, -> { DataCycleCore::Classification.count } => 1 do
        post classifications_path, xhr: true, params: {
          classification_tree_label_id: label.id,
          classification_alias: { translation: { de: { name: 'Cov Root Alias' } } }
        }
      end

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'create a nested classification alias under an existing tree node' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV CREATE NESTED', visibility: ['classification_administration'])
      parent = build_alias(label, 'Cov Parent')
      parent_tree = DataCycleCore::ClassificationTree.find_by(classification_alias_id: parent.id)

      post classifications_path, xhr: true, params: {
        classification_tree_label_id: label.id,
        classification_tree_id: parent_tree.id,
        classification_alias: { translation: { de: { name: 'Cov Child Alias' } } }
      }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'create with an invalid alias renders an error response' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV CREATE INVALID', visibility: ['classification_administration'])

      post classifications_path, xhr: true, params: {
        classification_tree_label_id: label.id,
        classification_alias: { translation: { de: { name: '' } } }
      }

      assert_response :success
      assert response.parsed_body.key?('error')
    end

    # ---------- update ----------
    test 'update a classification tree label' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV UPDATE LABEL', visibility: ['classification_administration'])

      patch classifications_path, xhr: true, params: {
        classification_tree_label: { id: label.id, name: 'COV UPDATE LABEL RENAMED' }
      }

      assert_response :success
      assert response.parsed_body.key?('html')
      assert_equal 'COV UPDATE LABEL RENAMED', label.reload.name
    end

    test 'update a classification alias and queue mappings when classification_ids change' do
      ca = @tags_alias # the Tags tree label is mappable
      target = DataCycleCore::Classification.create!(name: 'Cov Mapping Target')

      # ClassificationMappingJob runs in-process under test (it only forks outside test), so the
      # mapping change is actually applied and then rolled back with the test transaction.
      assert_difference -> { ca.reload.classification_ids.count }, 1 do
        patch classifications_path, xhr: true, params: {
          classification_alias: { id: ca.id, classification_ids: ca.classification_ids + [target.id] }
        }
      end

      assert_response :success
      assert response.parsed_body.key?('html')
      assert_includes ca.reload.classification_ids, target.id
    end

    test 'update with invalid data renders an error response' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV UPDATE INVALID', visibility: ['classification_administration'])

      patch classifications_path, xhr: true, params: {
        classification_tree_label: { id: label.id, name: '' }
      }

      assert_response :success
      assert response.parsed_body.key?('error')
    end

    # ---------- destroy ----------
    test 'destroy a classification tree label' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV DESTROY LABEL', visibility: ['classification_administration'])

      delete classifications_path, xhr: true, params: { classification_tree_label_id: label.id }

      assert_response :success
      assert response.parsed_body['deleted']
      assert_nil DataCycleCore::ClassificationTreeLabel.find_by(id: label.id)
    end

    test 'destroy a classification tree node' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV DESTROY TREE', visibility: ['classification_administration'])
      ca = build_alias(label, 'Cov Destroy Node')
      tree = DataCycleCore::ClassificationTree.find_by(classification_alias_id: ca.id)

      delete classifications_path, xhr: true, params: { classification_tree_id: tree.id }

      assert_response :success
      assert response.parsed_body['deleted']
    end

    test 'destroy without identifying param raises' do
      assert_raises(RuntimeError) do
        delete classifications_path, xhr: true, params: {}
      end
    end

    # ---------- download ----------
    test 'download a classification tree label as csv' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV DOWNLOAD', visibility: ['classification_administration'])
      build_alias(label, 'Cov Download Alias')

      get download_classifications_path(format: :csv), params: { classification_tree_label_id: label.id }

      assert_response :success
      assert_match 'text/csv', response.media_type
      assert_match(/sep=,/, response.body)
    end

    test 'download a classification tree label with contents and mapping variants' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV DOWNLOAD VARIANTS', visibility: ['classification_administration'], mappable: true)
      build_alias(label, 'Cov Download Variant Alias')

      ['mapping_import', 'mapping_export', 'mapping_export_inverse'].each do |specific_type|
        get download_classifications_path(format: :csv), params: { classification_tree_label_id: label.id, specific_type: }

        assert_response :success
      end

      get download_classifications_path(format: :csv), params: { classification_tree_label_id: label.id, include_contents: 'true' }

      assert_response :success
    end

    # ---------- move ----------
    test 'move a classification alias after a sibling' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV MOVE', visibility: ['classification_administration'])
      first = build_alias(label, 'Cov Move A')
      second = build_alias(label, 'Cov Move B')

      patch move_classifications_path, xhr: true, params: {
        classification_tree_label_id: label.id,
        classification_alias_id: first.id,
        previous_alias_id: second.id
      }

      assert_response :success
    end

    test 'move without a classification alias id responds not found' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV MOVE MISSING', visibility: ['classification_administration'])

      patch move_classifications_path(format: :json), params: { classification_tree_label_id: label.id }

      assert_response :not_found
    end

    # ---------- merge ----------
    test 'merge a classification alias into another' do
      label = DataCycleCore::ClassificationTreeLabel.create!(name: 'COV MERGE', visibility: ['classification_administration'])
      source = build_alias(label, 'Cov Merge Source')
      target = build_alias(label, 'Cov Merge Target')

      patch merge_classifications_path, xhr: true, params: {
        source_alias_id: source.id,
        target_alias_id: target.id
      }

      assert_response :success
    end

    test 'merge with a missing alias responds not found' do
      patch merge_classifications_path(format: :json), params: { source_alias_id: SecureRandom.uuid, target_alias_id: SecureRandom.uuid }

      assert_response :not_found
    end

    # ---------- link / unlink contents ----------
    # :link_contents / :unlink_contents are permission-list gated and not granted to the
    # seeded roles, so these exercise the lookup + authorization-denied path.
    test 'link_contents requires authorization' do
      concept_scheme = DataCycleCore::ConceptScheme.first
      collection = DataCycleCore::WatchList.create!(name: 'COV LINK WL', full_path: 'COV LINK WL', user_id: @admin.id)

      post link_contents_classifications_path(format: :json), params: {
        concept_scheme_link: { id: concept_scheme.id, collection_id: collection.id }
      }

      assert_response :unauthorized
    end

    test 'unlink_contents requires authorization' do
      concept_scheme = DataCycleCore::ConceptScheme.first
      collection = DataCycleCore::WatchList.create!(name: 'COV UNLINK WL', full_path: 'COV UNLINK WL', user_id: @admin.id)

      post unlink_contents_classifications_path(format: :json), params: {
        concept_scheme_link: { id: concept_scheme.id, collection_id: collection.id }
      }

      assert_response :unauthorized
    end

    # ---------- geometry ----------
    test 'geometry returns combined geojson as json' do
      post geometry_classifications_path(format: :json), params: { id: 'frame', concepts: [@tags_alias.id] }

      assert_response :success
    end

    test 'geometry returns a turbo stream replace' do
      post geometry_classifications_path, params: { id: 'frame', concepts: [@tags_alias.id] }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_equal 'text/vnd.turbo-stream.html', response.media_type
    end
  end
end
