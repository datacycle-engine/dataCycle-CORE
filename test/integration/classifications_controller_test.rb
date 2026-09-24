# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationsControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    setup do
      @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      # long-lived local test DBs can outlast the consent grace period, which would otherwise
      # redirect every HTML-format request in this file to the terms/privacy consent screen.
      @admin.update!(additional_attributes: (@admin.additional_attributes || {}).merge('terms_conditions_at' => Time.current, 'privacy_policy_at' => Time.current))
      sign_in(@admin)
      @tags_label = DataCycleCore::ConceptScheme.find_by(name: 'Tags')
      @tags_concept = DataCycleCore::Concept.for_tree('Tags').first
    end

    # a standard-role user, whose StoredFilter visibility is scoped to their own records (see
    # config/configurations/permissions/roles/standard.yml, stored_filter_actions), unlike @admin's
    # unrestricted access - mirrors the pattern in pentest_wave2_test.rb.
    def standard_role_user
      standard = DataCycleCore::Role.find_by(name: 'standard')
      DataCycleCore::User.where(email: 'cov_standard@datacycle.at').first_or_initialize.tap do |user|
        user.update!(given_name: 'Cov', family_name: 'Standard', password: 'vdr5pmx@juv9BMJ6ujt', role_id: standard.id, confirmed_at: 1.day.ago)
      end
    end

    # Externally managed classifications are only editable from rank 100 up -- every role below is
    # denied by ClassificationAliasAndChildrenNotExternalAndNotInternal, @admin (super_admin) included.
    def system_admin_user
      system_admin = DataCycleCore::Role.find_by(name: 'system_admin')
      DataCycleCore::User.where(email: 'cov_system_admin@datacycle.at').first_or_initialize.tap do |user|
        # rank 100 is rejected without OAuth providers (User#system_admin_requires_oauth)
        user.update!(given_name: 'Cov', family_name: 'SystemAdmin', password: 'vdr5pmx@juv9BMJ6ujt', role_id: system_admin.id, confirmed_at: 1.day.ago, providers: { keycloak: 'cov-system-admin' })
      end
    end

    # builds a standalone concept, named in every locale, mirroring ClassificationsController#create,
    # for the move/merge/download fixtures.
    def build_concept(concept_scheme, name, parent_concept: nil)
      concept = DataCycleCore::Concept.new(concept_scheme:, parent_concept:)
      I18n.available_locales.each { |l| I18n.with_locale(l) { concept.name = name } }
      concept.save!
      concept.reload
    end

    # #50677 hides a mapping of a flagged scheme, and a mapping is a `related` link: it attaches its
    # parent concept to every content its child classifies. Returns that link.
    def create_mapping_link(parent_concept, name)
      DataCycleCore::ConceptLink.create!(
        parent: parent_concept,
        child: build_concept(@tags_label, name),
        link_type: DataCycleCore::ConceptLink::LINK_TYPE_RELATED
      )
    end

    # ---------- index (json) ----------
    test 'index json by concept_scheme_id' do
      get classifications_path(format: :json), params: { concept_scheme_id: @tags_label.id }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'index json by concept_id' do
      get classifications_path(format: :json), params: { concept_id: @tags_concept.id }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    # the concept is shown as "queued" while its mapping job is outstanding. With
    # preserve_finished_jobs = false a failed job is the only row that lingers, so counting it would
    # leave the concept marked queued for good.
    test 'index reports a concept with an outstanding mapping job, but not one whose job failed' do
      # the listed concepts are the children of the requested one, not the requested concept itself
      concept_id = build_concept(@tags_label, 'Queued Mapping', parent_concept: @tags_concept).id
      queue_row = lambda do
        job = DataCycleCore::ClassificationMappingJob.new(concept_id)
        SolidQueue::Job.create!(queue_name: job.queue_name, class_name: job.class.name, arguments: job.serialize, concurrency_key: job.concurrency_key)
      end

      row = queue_row.call
      get classifications_path(format: :json), params: { concept_id: @tags_concept.id }

      assert_equal [concept_id], @controller.view_assigns['queued_concept_mappings']

      row.failed_with(StandardError.new('boom'))
      get classifications_path(format: :json), params: { concept_id: @tags_concept.id }

      assert_empty @controller.view_assigns['queued_concept_mappings']
    end

    test 'index json by mapped_concept_id' do
      get classifications_path(format: :json), params: { concept_scheme_id: @tags_label.id, mapped_concept_id: @tags_concept.id }

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
        exclude: [@tags_concept.id],
        exclude_tree_label: DataCycleCore::ConceptScheme.find_by(name: 'Inhaltstypen')&.id,
        with_geometry: 'false',
        preload: ['concept_scheme'],
        'disabled_unless_any?' => 'concept_polygons'
      }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    test 'search across all classifications with geometry filter' do
      get search_classifications_path(format: :json), params: { with_geometry: 'true', max: '5' }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    # #27657: the tooltip carries the external URI, but only for system_admin. Asserted here rather than
    # only in the helper test because the select2 endpoints build the tooltip through `helpers.`, which
    # is the one call path where the ability has to be resolved from the controller.
    def tooltip_for(concept)
      get search_classifications_path(format: :json), params: { tree_label: 'Tags', q: concept.internal_name, max: '50' }

      assert_response :success
      response.parsed_body.find { |r| r['id'] == concept.id }&.dig('dc_tooltip').to_s
    end

    test 'search exposes the external uri in the tooltip for a system_admin' do
      system_admin = DataCycleCore::User.find_by(email: 'system_admin@datacycle.at')

      assert_equal 'system_admin', system_admin.role_name

      @tags_concept.update!(uri: 'https://example.com/tag-uri')
      sign_out @admin
      sign_in system_admin

      assert_includes tooltip_for(@tags_concept), 'https://example.com/tag-uri'
    end

    # @admin is super_admin - the highest role below system_admin, so this proves the grant is
    # exclusive to system_admin rather than merely "not for editors".
    test 'search hides the external uri in the tooltip for a lower role' do
      assert_equal 'super_admin', @admin.role_name

      @tags_concept.update!(uri: 'https://example.com/tag-uri')

      assert_not_includes tooltip_for(@tags_concept), 'https://example.com/tag-uri'
    end

    # ---------- find ----------
    test 'find by concept ids within a concept scheme' do
      get find_classifications_path(format: :json), params: {
        ids: [@tags_concept.id],
        tree_label: 'Tags'
      }

      assert_response :success
      body = response.parsed_body

      assert_kind_of Array, body
      assert(body.any? { |c| c['id'] == @tags_concept.id })
    end

    # ---------- create ----------
    test 'create a classification tree label' do
      assert_difference -> { DataCycleCore::ConceptScheme.count } => 1 do
        post classifications_path, xhr: true, params: {
          concept_scheme: { name: 'COV LABEL', visibility: ['show', 'edit'] }
        }
      end

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'create a root concept under a concept scheme' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV CREATE ROOT', visibility: ['classification_administration'])

      # _concept_form renders the parent_concept_id hidden field for every new concept, so a root
      # is created with it blank rather than absent - Concept.find('') would raise RecordNotFound.
      assert_difference -> { DataCycleCore::Concept.count } => 1 do
        post classifications_path, xhr: true, params: {
          concept_scheme_id: label.id,
          parent_concept_id: '',
          concept: { translation: { de: { name: 'Cov Root Alias' } } }
        }
      end

      assert_response :success
      assert response.parsed_body.key?('html')
      assert_includes label.concepts.roots, DataCycleCore::Concept.find_by(internal_name: 'Cov Root Alias')
    end

    test 'create a nested concept under an existing parent' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV CREATE NESTED', visibility: ['classification_administration'])
      parent = build_concept(label, 'Cov Parent')

      post classifications_path, xhr: true, params: {
        concept_scheme_id: label.id,
        parent_concept_id: parent.id,
        concept: { translation: { de: { name: 'Cov Child Alias' } } }
      }

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    test 'create with an invalid concept renders an error response' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV CREATE INVALID', visibility: ['classification_administration'])

      post classifications_path, xhr: true, params: {
        concept_scheme_id: label.id,
        concept: { translation: { de: { name: '' } } }
      }

      assert_response :success
      assert response.parsed_body.key?('error')
    end

    # ---------- update ----------
    test 'update a classification tree label' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV UPDATE LABEL', visibility: ['classification_administration'])

      patch classifications_path, xhr: true, params: {
        concept_scheme: { id: label.id, name: 'COV UPDATE LABEL RENAMED' }
      }

      assert_response :success
      assert response.parsed_body.key?('html')
      assert_equal 'COV UPDATE LABEL RENAMED', label.reload.name
    end

    test 'update a concept and queue mappings when mapped_concept_ids change' do
      concept = @tags_concept # the Tags scheme is mappable
      target = build_concept(@tags_label, 'Cov Mapping Target')

      # the update enqueues ClassificationMappingJob; perform it inline so the mapping change is
      # actually applied (and then rolled back with the test transaction).
      assert_difference -> { concept.reload.mapped_concept_ids.count }, 1 do
        perform_enqueued_jobs do
          patch classifications_path, xhr: true, params: {
            concept: { id: concept.id, mapped_concept_ids: concept.mapped_concept_ids + [target.id] }
          }
        end
      end

      assert_response :success
      assert response.parsed_body.key?('html')
      assert_includes concept.reload.mapped_concept_ids, target.id
    end

    test 'update with invalid data renders an error response' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV UPDATE INVALID', visibility: ['classification_administration'])

      patch classifications_path, xhr: true, params: {
        concept_scheme: { id: label.id, name: '' }
      }

      assert_response :success
      assert response.parsed_body.key?('error')
    end

    # ---------- destroy ----------
    test 'destroy a classification tree label' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV DESTROY LABEL', visibility: ['classification_administration'])

      delete classifications_path, xhr: true, params: { concept_scheme_id: label.id }

      assert_response :success
      assert response.parsed_body['deleted']
      assert_nil DataCycleCore::ConceptScheme.find_by(id: label.id)
    end

    test 'destroy a classification tree node' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV DESTROY TREE', visibility: ['classification_administration'])
      concept = build_concept(label, 'Cov Destroy Node')

      delete classifications_path, xhr: true, params: { concept_id: concept.id }

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
      label = DataCycleCore::ConceptScheme.create!(name: 'COV DOWNLOAD', visibility: ['classification_administration'])
      build_concept(label, 'Cov Download Alias')

      get download_classifications_path(format: :csv), params: { concept_scheme_id: label.id }

      assert_response :success
      assert_match 'text/csv', response.media_type
      assert_match(/sep=,/, response.body)
    end

    test 'download a classification tree label with contents and mapping variants' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV DOWNLOAD VARIANTS', visibility: ['classification_administration'], mappable: true)
      build_concept(label, 'Cov Download Variant Alias')

      ['mapping_import', 'mapping_export', 'mapping_export_inverse'].each do |specific_type|
        get download_classifications_path(format: :csv), params: { concept_scheme_id: label.id, specific_type: }

        assert_response :success
      end

      get download_classifications_path(format: :csv), params: { concept_scheme_id: label.id, include_contents: 'true' }

      assert_response :success
    end

    # ---------- move ----------
    # Redmine #41458: move_params and merge_params underscore their keys, so the contract these
    # actions answer to is the camelCase classification_drag_and_drop.js sends. Posting snake_case
    # here would pass while the browser gets a 404, which is how the renamed keys shipped broken.
    test 'move a concept after a sibling' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV MOVE', visibility: ['classification_administration'])
      first = build_concept(label, 'Cov Move A')
      second = build_concept(label, 'Cov Move B')

      assert_equal [first, second], label.concepts.roots.to_a

      patch move_classifications_path, xhr: true, params: {
        conceptSchemeId: label.id,
        conceptId: first.id,
        previousConceptId: second.id
      }

      assert_response :success
      assert_equal [second, first], label.concepts.roots.to_a
    end

    test 'move a concept under a new parent' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV MOVE PARENT', visibility: ['classification_administration'])
      parent = build_concept(label, 'Cov Move Parent')
      child = build_concept(label, 'Cov Move Child')

      patch move_classifications_path, xhr: true, params: {
        conceptSchemeId: label.id,
        conceptId: child.id,
        newParentConceptId: parent.id
      }

      assert_response :success
      assert_equal [child], parent.children.reload.to_a
    end

    test 'move without a concept id responds not found' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV MOVE MISSING', visibility: ['classification_administration'])

      patch move_classifications_path(format: :json), params: { conceptSchemeId: label.id }

      assert_response :not_found
    end

    # ---------- merge ----------
    test 'merge a concept into another' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV MERGE', visibility: ['classification_administration'])
      source = build_concept(label, 'Cov Merge Source')
      target = build_concept(label, 'Cov Merge Target')

      patch merge_classifications_path, xhr: true, params: {
        sourceConceptId: source.id,
        targetConceptId: target.id
      }

      assert_response :success
      assert_not DataCycleCore::Concept.exists?(source.id)
    end

    # Redmine #51232: the refusal has to reach the editor as a callout, not a 500. The drag-and-drop
    # JS keys off the error payload for both the callout and for leaving the source in the tree, so
    # the 200 and the error key are what it needs.
    test 'merge of concepts from different external systems responds with an error message' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV MERGE EXT', visibility: ['classification_administration'])
      es = DataCycleCore::ExternalSystem.first
      other_es = DataCycleCore::ExternalSystem.create!(name: 'Cov Merge Other', identifier: 'cov-merge-other')
      source = build_concept(label, 'Cov Ext Source')
      target = build_concept(label, 'Cov Ext Target')
      source.update!(external_system_id: es.id, external_key: 'COV-SOURCE-KEY')
      target.update!(external_system_id: other_es.id, external_key: 'COV-TARGET-KEY')
      sign_in(system_admin_user)

      patch merge_classifications_path, xhr: true, params: {
        sourceConceptId: source.id,
        targetConceptId: target.id
      }

      assert_response :success
      assert_predicate response.parsed_body['error'], :present?
      assert_not source.reload.destroyed?
    end

    # Redmine #51232: dropping an imported concept onto a config concept is the case an editor cleaning
    # up import duplicates actually hits. The config concept's identity is (NULL, full_path), so the
    # merge would overwrite it and the next dc:update would insert the node a second time.
    test 'merge onto a config concept responds with an error message' do
      label = DataCycleCore::ConceptScheme.create!(name: 'COV MERGE CFG', visibility: ['classification_administration'])
      es = DataCycleCore::ExternalSystem.first
      source = build_concept(label, 'Cov Cfg Source')
      target = build_concept(label, 'Cov Cfg Target')
      source.update!(external_system_id: es.id, external_key: 'COV-SOURCE-KEY')
      target.update!(external_key: 'COV MERGE CFG > Cov Cfg Target')
      sign_in(system_admin_user)

      patch merge_classifications_path, xhr: true, params: {
        sourceConceptId: source.id,
        targetConceptId: target.id
      }

      assert_response :success
      assert_predicate response.parsed_body['error'], :present?
      assert_not source.reload.destroyed?
      assert_equal 'COV MERGE CFG > Cov Cfg Target', target.reload.external_key
    end

    test 'merge with a missing concept responds not found' do
      patch merge_classifications_path(format: :json), params: { sourceConceptId: SecureRandom.uuid, targetConceptId: SecureRandom.uuid }

      assert_response :not_found
    end

    # ---------- link / unlink contents ----------
    # :link_contents / :unlink_contents are granted on DataCycleCore::ConceptScheme — the
    # record the button's can? checks too — and @admin is the super_admin that grant belongs to.
    # Authorizing the ConceptScheme instead matched no rule, so the role being offered the action got a
    # 401 on submit. These two asserted that 401, which is how the bug survived.
    test 'link_contents is authorized for the granted role' do
      concept_scheme = DataCycleCore::ConceptScheme.first
      collection = DataCycleCore::WatchList.create!(name: 'COV LINK WL', full_path: 'COV LINK WL', user_id: @admin.id)

      post link_contents_classifications_path(format: :json), params: {
        concept_scheme_link: { id: concept_scheme.id, collection_id: collection.id }
      }

      assert_response :success
    end

    test 'unlink_contents is authorized for the granted role' do
      concept_scheme = DataCycleCore::ConceptScheme.first
      collection = DataCycleCore::WatchList.create!(name: 'COV UNLINK WL', full_path: 'COV UNLINK WL', user_id: @admin.id)

      post unlink_contents_classifications_path(format: :json), params: {
        concept_scheme_link: { id: concept_scheme.id, collection_id: collection.id }
      }

      assert_response :success
    end

    test 'link_contents requires authorization' do
      sign_in(standard_role_user)
      concept_scheme = DataCycleCore::ConceptScheme.first
      collection = DataCycleCore::WatchList.create!(name: 'COV LINK DENY WL', full_path: 'COV LINK DENY WL', user_id: @admin.id)

      post link_contents_classifications_path(format: :json), params: {
        concept_scheme_link: { id: concept_scheme.id, collection_id: collection.id }
      }

      assert_response :unauthorized
    end

    test 'unlink_contents requires authorization' do
      sign_in(standard_role_user)
      concept_scheme = DataCycleCore::ConceptScheme.first
      collection = DataCycleCore::WatchList.create!(name: 'COV UNLINK DENY WL', full_path: 'COV UNLINK DENY WL', user_id: @admin.id)

      post unlink_contents_classifications_path(format: :json), params: {
        concept_scheme_link: { id: concept_scheme.id, collection_id: collection.id }
      }

      assert_response :unauthorized
    end

    # ---------- geometry ----------
    test 'geometry returns combined geojson as json' do
      post geometry_classifications_path(format: :json), params: { id: 'frame', concepts: [@tags_concept.id] }

      assert_response :success
    end

    test 'geometry returns a turbo stream replace' do
      post geometry_classifications_path, params: { id: 'frame', concepts: [@tags_concept.id] }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_equal 'text/vnd.turbo-stream.html', response.media_type
    end

    # ---------- hidden_mappings on the tree label (#50677) ----------
    # Tags is a non-external tree label, so @admin (admin@datacycle.at is seeded as super_admin, which
    # holds :update_hidden_mappings) may set the flag; `hidden_mappings` decides whether its concepts
    # show up on contents that only reach them through a mapping.
    test 'update sets hidden_mappings on a classification tree label' do
      assert @admin.ability.can?(:update_hidden_mappings, @tags_label) # the grant this test relies on

      patch classifications_path, xhr: true, params: {
        concept_scheme: { id: @tags_label.id, name: @tags_label.name, hidden_mappings: true }
      }

      assert_response :success
      assert_predicate @tags_label.reload, :hidden_mappings?
    end

    test 'update removes hidden_mappings from a classification tree label' do
      @tags_label.update!(hidden_mappings: true)

      patch classifications_path, xhr: true, params: {
        concept_scheme: { id: @tags_label.id, name: @tags_label.name, hidden_mappings: false }
      }

      assert_response :success
      assert_not_predicate @tags_label.reload, :hidden_mappings?
    end

    # #50677: the form only renders the checkbox for holders of :update_hidden_mappings, and update
    # authorizes nothing by itself — so the parameter has to be dropped for everyone else. An admin
    # (rank 10) has :update on the tree label but not :update_hidden_mappings: the rest of the payload
    # applies, the flag does not.
    test 'update ignores hidden_mappings without the update_hidden_mappings ability' do
      editor = DataCycleCore::User.find_by(email: 'tester@datacycle.at') # role: admin (rank 10)

      # the premise: this role may edit the tree label but does not hold :update_hidden_mappings.
      # Asserted so the test cannot quietly turn vacuous if admin.yml ever grants it.
      assert editor.ability.can?(:update, @tags_label)
      assert_not editor.ability.can?(:update_hidden_mappings, @tags_label)

      sign_in(editor)

      patch classifications_path, xhr: true, params: {
        concept_scheme: { id: @tags_label.id, name: 'Cov Tags Renamed', hidden_mappings: true }
      }

      assert_response :success
      assert_not_predicate @tags_label.reload, :hidden_mappings?
      assert_equal 'Cov Tags Renamed', @tags_label.name # the rest of the payload still applied
    end

    # #50677: hidden_mappings is not the only attribute of these two forms whose field is gated on an
    # ability of its own — ClassificationsController::GATED_ATTRIBUTES drops every one of them that the
    # current user may not write. `internal`, `mappable` and `change_behaviour` are rendered under
    # :update_internal / :update_mappable / :update_change_behaviour, none of which any role yml grants:
    # only system_admin reaches them through :manage.
    test 'update ignores the tree label attributes gated on an ability the user lacks' do
      internal_before = @tags_label.internal
      mappable_before = @tags_label.mappable
      change_behaviour_before = @tags_label.change_behaviour

      # the premise: super_admin edits the tree label but holds none of the attribute gates
      assert @admin.ability.can?(:update, @tags_label)
      assert_not @admin.ability.can?(:update_internal, @tags_label)
      assert_not @admin.ability.can?(:update_mappable, @tags_label)
      assert_not @admin.ability.can?(:update_change_behaviour, @tags_label)

      patch classifications_path, xhr: true, params: {
        concept_scheme: { id: @tags_label.id, name: 'Cov Tags Gated', internal: !internal_before, mappable: !mappable_before, change_behaviour: ['clear_cache'] }
      }

      assert_response :success
      @tags_label.reload

      assert_equal internal_before, @tags_label.internal
      assert_equal mappable_before, @tags_label.mappable
      assert_equal change_behaviour_before, @tags_label.change_behaviour
      assert_equal 'Cov Tags Gated', @tags_label.name # the rest of the payload still applied
    end

    test 'update ignores the concept attributes gated on an ability the user lacks' do
      internal_before = @tags_concept.internal

      assert_not @admin.ability.can?(:update_internal, @tags_concept)

      patch classifications_path, xhr: true, params: {
        concept: { id: @tags_concept.id, internal: !internal_before, description: 'Cov Alias Gated' }
      }

      assert_response :success
      @tags_concept.reload

      assert_equal internal_before, @tags_concept.internal
      assert_equal 'Cov Alias Gated', @tags_concept.description # the rest of the payload still applied
    end

    # :set_color is the one of these gates the shipped roles do hold — but on SubjectNotInternal, so an
    # internal concept is where the drop is observable at all. ui_configs is dropped whole: :color is its
    # only permitted sub-key.
    test 'update ignores the concept color without the set_color ability' do
      internal_concept = build_concept(@tags_label, 'Cov Gated Color')
      internal_concept.update!(internal: true, ui_configs: { 'color' => '#aabbcc' })

      # the premise: the gate is granted, and closed only because this concept is internal
      assert @admin.ability.can?(:set_color, @tags_concept)
      assert_not @admin.ability.can?(:set_color, internal_concept)

      patch classifications_path, xhr: true, params: {
        concept: { id: internal_concept.id, ui_configs: { color: '#ff0000' }, description: 'Cov Color Gated' }
      }

      assert_response :success
      internal_concept.reload

      assert_equal '#aabbcc', internal_concept.color
      assert_equal 'Cov Color Gated', internal_concept.description # the rest of the payload still applied
    end

    # a mapping group of a flagged tree does not attach its concept to a content any more
    test 'hidden_mappings excludes the tree\'s mapping groups from the visible scope' do
      mapping = create_mapping_link(@tags_concept, 'Cov Hidden Mappings')

      assert_includes DataCycleCore::ConceptLink.visible.ids, mapping.id

      @tags_label.update!(hidden_mappings: true)

      assert_not_includes DataCycleCore::ConceptLink.visible.ids, mapping.id
      # the concept's own broader link is tree structure, never a mapping, so it stays visible
      assert_includes DataCycleCore::ConceptLink.visible.ids, @tags_concept.parent_concept_link.id
    end

    # ---------- stored_filter_usage (#43524) ----------
    test 'stored_filter_usage renders the stored filters that use the given classification' do
      stored_filter = DataCycleCore::StoredFilter.create!(
        name: 'Cov Usage Direct', user: @admin, language: ['de'],
        parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'concept_ids_with_subtree', 'v' => [@tags_concept.id] }]
      )

      get stored_filter_usage_classifications_path, params: { id: @tags_concept.id }

      assert_response :success
      assert_select('.stored-filter-usage-list button', text: /#{Regexp.escape(stored_filter.name)}/)
      # POST via a real form (ids as hidden fields), not a GET link with ids in the query string,
      # which can exceed the URI length limit for a classification used by hundreds of searches (#43524).
      assert_select('.stored-filter-usage-list form.button_to[action=?]', saved_searches_stored_filters_path)
      assert_select('.stored-filter-usage-list input[name="ids[]"][value=?]', stored_filter.id)
      # A single item is an exact, already-identified search, not a classification-restricted browse -
      # no classification_id (so no chip); q makes the restriction visible in the search field instead.
      assert_select('.stored-filter-usage-list input[name="classification_id"]', count: 0)
      assert_select('.stored-filter-usage-list input[name="q"][value=?]', stored_filter.name)
    end

    test 'stored_filter_usage renders a "show all" button in the footer with every matching stored filter id and the classification_id as hidden fields' do
      first = DataCycleCore::StoredFilter.create!(
        name: 'Cov Usage A', user: @admin, language: ['de'],
        parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'concept_ids_with_subtree', 'v' => [@tags_concept.id] }]
      )
      second = DataCycleCore::StoredFilter.create!(
        name: 'Cov Usage B', user: @admin, language: ['de'],
        parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'concept_ids_with_subtree', 'v' => [@tags_concept.id] }]
      )

      get stored_filter_usage_classifications_path, params: { id: @tags_concept.id }

      assert_response :success
      assert_select('.reveal-footer form.button_to[action=?]', saved_searches_stored_filters_path)
      assert_select('.reveal-footer .stored-filter-usage-show-all')
      assert_select('.reveal-footer input[name="ids[]"][value=?]', first.id)
      assert_select('.reveal-footer input[name="ids[]"][value=?]', second.id)
      # Unlike the single-item links, "show all" is a genuine classification-restricted browse, so it
      # does carry classification_id (see StoredFiltersController#saved_searches for the chip it renders).
      assert_select('.reveal-footer input[name="classification_id"][value=?]', @tags_concept.id)
    end

    # #43524 (review finding): the global usage count must not leak names/links of stored filters
    # the current user cannot open - only accessible ones are listed, the rest are just counted.
    test 'stored_filter_usage lists only accessible stored filters and reports the rest as a hidden count' do
      standard_user = standard_role_user
      own = DataCycleCore::StoredFilter.create!(
        name: 'Cov Own', user: standard_user, language: ['de'],
        parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'concept_ids_with_subtree', 'v' => [@tags_concept.id] }]
      )
      others = DataCycleCore::StoredFilter.create!(
        name: 'Cov Others', user: @admin, language: ['de'],
        parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'concept_ids_with_subtree', 'v' => [@tags_concept.id] }]
      )

      sign_in(standard_user)
      get stored_filter_usage_classifications_path, params: { id: @tags_concept.id }

      assert_response :success
      assert_select('.stored-filter-usage-list button', text: /#{Regexp.escape(own.name)}/)
      assert_select('.stored-filter-usage-list', text: /#{Regexp.escape(others.name)}/, count: 0)
      assert_select('.stored-filter-usage-hidden-count', text: /1/)
    end

    test 'stored_filter_usage reports a hidden count without a misleading empty message when nothing is accessible' do
      standard_user = standard_role_user
      first = DataCycleCore::StoredFilter.create!(
        name: 'Cov Others A', user: @admin, language: ['de'],
        parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'concept_ids_with_subtree', 'v' => [@tags_concept.id] }]
      )
      second = DataCycleCore::StoredFilter.create!(
        name: 'Cov Others B', user: @admin, language: ['de'],
        parameters: [{ 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'concept_ids_with_subtree', 'v' => [@tags_concept.id] }]
      )

      sign_in(standard_user)
      get stored_filter_usage_classifications_path, params: { id: @tags_concept.id }

      assert_response :success
      assert_select('.stored-filter-usage-list', count: 0)
      assert_select('p.empty', count: 0)
      assert_select('.reveal-footer', count: 0)
      assert_select('.stored-filter-usage-hidden-count', text: /2/)
      assert_no_match first.name, response.body
      assert_no_match second.name, response.body
    end

    test 'stored_filter_usage renders an empty result for a classification not used by any stored filter' do
      unused_concept = build_concept(@tags_label, 'Cov Unused Alias')

      get stored_filter_usage_classifications_path, params: { id: unused_concept.id }

      assert_response :success
      assert_select('p.empty')
    end
  end
end
