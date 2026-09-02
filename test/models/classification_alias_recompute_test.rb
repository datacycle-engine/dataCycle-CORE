# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  # Recomputation of computed properties that opt in via
  # compute.recompute_on_classification_change, plus the search/webhook cache-invalidation
  # fan-out, after the kinds of classification change that stale such a value: a mapping delta
  # (driven through the production path, ClassificationMappingJob), a concept rename and a move.
  class ClassificationAliasRecomputeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @tag1 = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 1').first
      @tag3 = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 3').first
      @nested_tag = DataCycleCore::Concept.for_tree('Tags').with_name('Nested Tag 1').first # child of Tag 3
      @source1 = DataCycleCore::Concept.for_tree('Test Mapping').with_name('Test1').first
      @source2 = DataCycleCore::Concept.for_tree('Test Mapping').with_name('Test2').first
    end

    # icon only on the top-level 'Tag 3', not on its child 'Nested Tag 1'
    def with_icons(&)
      DataCycleCore.stub(:classification_icons, { @tag3.id => 'tag3.svg' }, &)
    end

    def create_content(source_concept)
      DataCycleCore::TestPreparations.create_content(
        template_name: 'PrimaryIcon-Place',
        data_hash: { 'name' => "Recompute #{source_concept.classification_id}", 'universal_classifications' => [source_concept.classification_id] }
      )
    end

    # runs a mapping change through the real job (inline in test) and performs the recompute
    # fan-out it enqueues (CacheInvalidationDestroyJob); ActionCable is stubbed
    def apply_mapping(alias_id, insert: [], delete: [])
      ActionCable.server.stub(:broadcast, ->(*) {}) do
        perform_enqueued_jobs do
          DataCycleCore::ClassificationMappingJob.new.perform(alias_id, insert, delete)
        end
      end
    end

    def stored_icon_ids(content)
      Array.wrap(content.reload.get_data_hash['primary_icon_classifications'])
    end

    # content whose parent_tag_name compute stores the name of the given concept's parent
    def create_parent_tag_content(concept)
      DataCycleCore::TestPreparations.create_content(
        template_name: 'ComputeTreeLabel-Place',
        data_hash: { 'name' => "Below #{concept.name}", 'universal_classifications' => [concept.classification_id] }
      )
    end

    def stored_parent_tag_name(content)
      DataCycleCore::Thing.find(content.id).get_data_hash['parent_tag_name']
    end

    # renames a concept and runs the jobs the rename enqueues
    def rename_concept(concept, name)
      ActionCable.server.stub(:broadcast, ->(*) {}) do
        perform_enqueued_jobs do
          DataCycleCore::ClassificationAlias.find(concept.id).update!(name:)
        end
      end
    end

    # re-parents a concept within its tree and runs the jobs the move enqueues
    def move_concept(concept, new_parent)
      ActionCable.server.stub(:broadcast, ->(*) {}) do
        perform_enqueued_jobs do
          alias_record = DataCycleCore::ClassificationAlias.find(concept.id)
          alias_record.move_to_tree(new_parent.id, alias_record.classification_tree_label.id)
        end
      end
    end

    # captures CacheInvalidationDestroyJob enqueues instead of running them inline, so a
    # mapping delta's fan-out can be inspected: [class_name, alias_id, method_name, thing_ids]
    def capture_destroy_jobs(&)
      calls = []
      DataCycleCore::CacheInvalidationDestroyJob.stub(:perform_later, ->(*args) { calls << args }, &)
      calls
    end

    test 'templates opting in via recompute_on_classification_change are registered with their override trees' do
      properties = DataCycleCore::ThingTemplate.classification_change_computed_properties

      assert_equal(['primary_icon_classifications'], properties.dig('PrimaryIcon-Place', :computed_property_names))
      assert_equal(['Märkte', 'Tags'], properties.dig('PrimaryIcon-Place', :tree_labels).sort)
    end

    # A compute whose only parameter is universal has no parameter that could carry a tree_label,
    # so the tree has to come from the property's own config — otherwise tree_labels stays empty
    # and the flag never matches an alias. The two compute utilities disagree on where they read
    # tree_label from, hence one template per convention.
    test 'a universal-only compute registers the tree_label declared inside its compute hash' do
      properties = DataCycleCore::ThingTemplate.classification_change_computed_properties

      assert_equal(['parent_tag_name'], properties.dig('ComputeTreeLabel-Place', :computed_property_names))
      assert_equal(['Tags'], properties.dig('ComputeTreeLabel-Place', :tree_labels))
    end

    test 'a universal-only compute registers the tree_label declared on the property' do
      properties = DataCycleCore::ThingTemplate.classification_change_computed_properties

      assert_equal(['mapped_tag'], properties.dig('PropertyTreeLabel-Place', :computed_property_names))
      assert_equal(['Tags'], properties.dig('PropertyTreeLabel-Place', :tree_labels))
    end

    # An empty gate must not mean both "nothing classification-related" and "we failed to derive the
    # tree" — the second is this ticket, on a property nobody hand-wrote.
    test 'a flagged compute with no classification dependency at all is not registered' do
      properties = DataCycleCore::ThingTemplate.classification_change_computed_properties

      # the template does own a tree-bound property, just not as a parameter of the flagged compute: the
      # parameter lookup asks for the union of every compute's parameter names, so keying it by template
      # alone would gate this one on 'Tags'
      assert_equal('Tags', DataCycleCore::ThingTemplate.find_by(template_name: 'NoClassificationCompute-Place').property_definitions.dig('primary_icon_tags', 'tree_label'))
      assert_not(properties.key?('NoClassificationCompute-Place'))
    end

    # Imported here rather than into the shared test data: it matches every tree, so a permanent
    # registration would make "a tree with no opted-in property" impossible for the tests below.
    test 'a flagged compute whose tree cannot be derived is gated on every tree, not on none' do
      importer = DataCycleCore::MasterData::Templates::TemplateImporter.new(template_paths: [Rails.root.join('..', 'data_types', 'master_data', 'ungated_compute_set')])
      importer.import

      assert_empty(importer.errors)

      properties = DataCycleCore::ThingTemplate.classification_change_computed_properties

      assert_equal(['parent_tag_name'], properties.dig('UngatedCompute-Place', :computed_property_names))
      assert_empty(properties.dig('UngatedCompute-Place', :tree_labels))
      assert(properties.dig('UngatedCompute-Place', :all_tree_labels))
      assert_includes(DataCycleCore::ThingTemplate.classification_change_computed_properties_for('Test Mapping').keys, 'UngatedCompute-Place')
    end

    test 'no registered template ends up with a gate that can never match' do
      ungated = DataCycleCore::ThingTemplate.classification_change_computed_properties
        .select { |_template_name, config| config[:tree_labels].blank? && !config[:all_tree_labels] }

      assert_empty(ungated)
    end

    # otherwise every compute pairing a declared tree with universal_classifications recomputes on every tree
    test 'a declared tree_label keeps a universal parameter from widening the gate' do
      properties = DataCycleCore::ThingTemplate.classification_change_computed_properties

      assert_not(properties.dig('ComputeTreeLabel-Place', :all_tree_labels))
      assert_not(properties.dig('PropertyTreeLabel-Place', :all_tree_labels))
      assert_not(properties.dig('PrimaryIcon-Place', :all_tree_labels))
    end

    test 'classification_change_computed_properties_for is empty for a blank tree label' do
      assert_empty(DataCycleCore::ThingTemplate.classification_change_computed_properties_for(nil))
      assert_empty(DataCycleCore::ThingTemplate.classification_change_computed_properties_for(''))
    end

    # A rename writes no content, so nothing else recomputes a value that stores the concept's name.
    # The stale contents hang *below* the renamed concept (parent_classification_name stores the
    # parent's name), which is what makes this the linked_contents fan-out rather than the directly
    # assigned things a mapping delta recomputes.
    test 'renaming a concept recomputes a stored parent name on the contents below it' do
      content = create_parent_tag_content(@nested_tag)

      assert_equal('Tag 3', stored_parent_tag_name(content))

      rename_concept(@tag3, 'Tag 3 renamed')

      assert_equal('Tag 3 renamed', stored_parent_tag_name(content))
    end

    # The set is the whole linked_contents of the renamed concept — tens of thousands on a broadly
    # used one. Resolved in the job, so it must not be plucked into the job arguments (from where it
    # would also reach the hashed concurrency key).
    test 'renaming a concept enqueues the recompute without carrying the affected ids' do
      create_parent_tag_content(@nested_tag)

      calls = capture_destroy_jobs { rename_concept(@tag3, 'Tag 3 renamed') }
      recompute_calls = calls.select { |_class_name, _id, method_name, _ids| method_name == 'update_linked_things_computed_properties' }

      assert_equal(1, recompute_calls.size)
      assert_equal(@tag3.id, recompute_calls.first.second)
      assert_nil(recompute_calls.first.last)
    end

    test 'renaming a concept in a tree with no opted-in property enqueues nothing' do
      create_parent_tag_content(@nested_tag)

      calls = capture_destroy_jobs { rename_concept(@source1, 'Test1 renamed') }

      assert_not_includes(calls.map(&:third), 'update_linked_things_computed_properties')
    end

    # a concept with no linked content would enqueue a job that resolves an empty set
    test 'renaming a concept with no linked contents enqueues nothing' do
      calls = capture_destroy_jobs { rename_concept(@tag3, 'Tag 3 renamed') }

      assert_not_includes(calls.map(&:third), 'update_linked_things_computed_properties')
    end

    # A move stales the same values and writes no content either, and it lands on classification_trees,
    # so no after_update on the alias fires — only move_to_tree can enqueue this.
    test 'moving a concept recomputes a stored parent name on the contents below it' do
      content = create_parent_tag_content(@nested_tag)

      assert_equal('Tag 3', stored_parent_tag_name(content))

      move_concept(@nested_tag, @tag1)

      assert_equal('Tag 1', stored_parent_tag_name(content))
    end

    test 'moving a concept in a tree with no opted-in property enqueues nothing' do
      create_content(@source1) # so the enqueue turns on the tree gate, not on the empty-contents one

      calls = capture_destroy_jobs { move_concept(@source1, @source2) }

      assert_not_includes(calls.map(&:third), 'update_linked_things_computed_properties')
    end

    # the gate reads the tree the concept sits in *now* — a memoized association serving the tree it came
    # from would skip the recompute exactly when the destination is the tree that opted in
    test 'moving a concept into a tree with an opted-in property enqueues the recompute' do
      create_content(@source1)
      alias_record = DataCycleCore::ClassificationAlias.find(@source1.id)
      alias_record.classification_tree_label # memoize the old tree before the move

      calls = capture_destroy_jobs do
        ActionCable.server.stub(:broadcast, ->(*) {}) do
          alias_record.move_to_tree(@tag1.id, DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id)
        end
      end

      assert_includes(calls.map(&:third), 'update_linked_things_computed_properties')
    end

    test 'adding a mapping recomputes the affected contents' do
      with_icons do
        content = create_content(@source1)

        assert_empty(stored_icon_ids(content))

        apply_mapping(@tag3.id, insert: [@source1.classification_id])

        assert_equal([@tag3.classification_id], stored_icon_ids(content))
      end
    end

    test 'removing a mapping recomputes contents whose stored icon sits on an ancestor of the leaf' do
      with_icons do
        content = create_content(@source1)

        # map onto the icon-less child => icon resolves to its ancestor 'Tag 3'
        apply_mapping(@nested_tag.id, insert: [@source1.classification_id])

        assert_equal([@tag3.classification_id], stored_icon_ids(content))

        # removing the mapping must clear the icon — the content is no longer linked to
        # the nested alias, so recomputing that alias's linked_contents would miss it
        apply_mapping(@nested_tag.id, delete: [@source1.classification_id])

        assert_empty(stored_icon_ids(content))
      end
    end

    test 'a multi-classification mapping delta recomputes every affected content (union)' do
      with_icons do
        content1 = create_content(@source1)
        content2 = create_content(@source2)

        # both mapped in a single delta; the recompute must cover both contents, not just
        # the last classification's (CacheInvalidationDestroyJob dedups on alias+method)
        apply_mapping(@tag3.id, insert: [@source1.classification_id, @source2.classification_id])

        assert_equal([@tag3.classification_id], stored_icon_ids(content1))
        assert_equal([@tag3.classification_id], stored_icon_ids(content2))
      end
    end

    test 'a multi-classification mapping delta enqueues one search-update job for the union of affected contents' do
      content1 = create_content(@source1)
      content2 = create_content(@source2)

      calls = capture_destroy_jobs do
        apply_mapping(@tag3.id, insert: [@source1.classification_id, @source2.classification_id])
      end

      search_calls = calls.select { |_class_name, _id, method_name, _ids| method_name == 'update_things_search' }

      # one job for the whole delta (not one per classification), carrying the full union of
      # affected contents — per-classification jobs would collapse to the last one because
      # CacheInvalidationDestroyJob dedups on (alias, method) without thing_ids
      assert_equal(1, search_calls.size)
      assert_includes(search_calls.first.last, content1.id)
      assert_includes(search_calls.first.last, content2.id)
    end

    test 'a change on an alias in an unrelated tree does not recompute the contents' do
      with_icons do
        content = create_content(@source1)
        source_alias = DataCycleCore::ClassificationAlias.find(@source1.id)

        # 'Test Mapping' is not an override tree => the job must skip recomputation
        assert_no_changes -> { content.reload.updated_at } do
          DataCycleCore::CacheInvalidationDestroyJob.perform_now(
            source_alias.class.name, source_alias.id, 'update_things_computed_properties', [content.id]
          )
        end
      end
    end
  end
end
