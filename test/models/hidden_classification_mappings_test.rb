# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  # Redmine #47172/#50677: a classification tree can be flagged with hidden_mappings. Its concepts are
  # then excluded from collected_classification_contents reads (filter, detail, API, search) on every
  # content that only reaches them through a mapping, while they stay resolvable for computed
  # attributes via concept_links. Not affected: a direct classification from that tree (and its broader
  # ancestors), and concepts of other trees reached by a mapping *out of* the flagged tree.
  #
  # The behaviour is exercised against BOTH collected_classification_contents generators: the
  # non-transitive one (core default) and the transitive one (enabled in projects like BayernCloud).
  module HiddenClassificationMappingSharedTests
    extend ActiveSupport::Concern

    included do
      test 'a mapping into an unflagged tree materialises into CCC and reaches computed attributes' do
        assert_equal [['direct', false]], ccc_for(@src.id)
        assert_equal [['related', false]], ccc_for(@tt.id)
        assert_equal [['broader', false]], ccc_for(@ttp.id)

        assert_includes @src.concept.mapped_inverse_concepts.pluck(:id), @tt.id
        assert_includes @content.classification_aliases.map(&:id), @tt.id # search-index source
      end

      test 'flagging the tree removes its mapped concepts from CCC reads and search but keeps them for computed attributes' do
        hide_target_tree!

        # the mapped concept and its ancestors inside the flagged tree are flagged hidden
        assert_equal [['related', true]], ccc_for(@tt.id)
        assert_equal [['broader', true]], ccc_for(@ttp.id)
        # the direct classification of the unflagged source tree is untouched
        assert_equal [['direct', false]], ccc_for(@src.id)

        # read scopes / associations exclude them
        assert_not_includes @content.collected_classification_contents.without_hidden.pluck(:classification_alias_id), @tt.id
        assert_not_includes @content.full_classification_aliases.map(&:id), @tt.id
        assert_not_includes @content.classification_aliases.map(&:id), @tt.id # search-index source
        assert_includes @content.classification_aliases.map(&:id), @src.id

        # concept_links keep link_type='related', so computed attributes still resolve the mapping
        assert_equal 'related', ConceptLink.find(@mapping.id).link_type
        assert_includes @src.concept.mapped_inverse_concepts.pluck(:id), @tt.id
      end

      # #50677: search index and webhooks have to fan out over the contents that *reach* this tree, not
      # over ClassificationTreeLabel#things (the directly classified ones) — a content carrying one of
      # its concepts only through a mapping is by definition not among those, and it is exactly the one
      # the flag changes.
      test 'flagging the tree reindexes and webhooks the contents reaching it only through a mapping' do
        label = DataCycleCore::ClassificationTreeLabel.find(@target_tree.id)

        # the premises this guards
        assert_not_includes label.things.ids, @content.id
        assert_includes label.change_behaviour, 'trigger_webhooks'
        assert_includes indexed_alias_ids, @tt.id

        hide_target_tree!

        assert_not_includes indexed_alias_ids, @tt.id
        assert_includes indexed_alias_ids, @src.id

        # both side effects are fanned out into CacheInvalidationDestroyJob batches — the callback runs
        # the refresh on its own instance, so the scope is asserted by invoking it here
        enqueued = []
        DataCycleCore::CacheInvalidationDestroyJob.stub(:perform_later, ->(_class_name, reference, method_name, thing_ids) { enqueued << [reference, method_name, thing_ids] }) do
          label.send(:refresh_hidden_mappings)
        end

        by_method = enqueued.group_by { |(_, method_name, _)| method_name }.transform_values { |jobs| jobs.flat_map(&:last) }

        assert_includes by_method['execute_things_webhooks_destroy'].to_a, @content.id
        assert_includes by_method['update_things_search'].to_a, @content.id
        # the batch index has to reach arguments[1]: UniqueApplicationJob dedups on it, so a bare tree id
        # would make every batch delete the ones enqueued before it
        assert_equal ["#{label.id}:0"], enqueued.map(&:first).uniq
      end

      # #50677: refresh_hidden_mappings webhooks a superset of `things`, so the things-webhook callback
      # has to step aside when the same update flips the flag — otherwise renaming a tree and ticking
      # the checkbox in one save delivers every directly classified content twice. Asserted on freshly
      # loaded instances: cached_attributes_changed? memoizes, so one instance cannot answer for two
      # updates.
      test 'a combined name and flag change webhooks the contents only once' do
        original_name = @target_tree.name

        rename_only = DataCycleCore::ClassificationTreeLabel.find(@target_tree.id)
        rename_only.update!(name: "#{original_name}_renamed")

        # the premise this guards: a rename on its own does webhook through the things callback
        assert rename_only.send(:trigger_things_webhooks?)

        combined = DataCycleCore::ClassificationTreeLabel.find(@target_tree.id)
        combined.update!(name: "#{original_name}_again", hidden_mappings: true)

        # same rename, now accompanied by the flag — refresh_hidden_mappings covers these contents
        assert_not combined.send(:trigger_things_webhooks?)
        assert_predicate combined, :trigger_webhooks?
      ensure
        DataCycleCore::ClassificationTreeLabel.find(@target_tree.id).update!(name: original_name)
      end

      test 'a mapping created after the tree was flagged is hidden as well' do
        hide_target_tree!

        second = @target_tree.create_classification_alias('TTP', 'TT2')
        DataCycleCore::ClassificationGroup.create!(classification: @src.primary_classification, classification_alias: second)
        @content.reload

        assert_equal [['related', true]], ccc_for(second.id)
        assert_not_includes @content.classification_aliases.map(&:id), second.id
      end

      test 'unflagging the tree makes its mapped concepts visible again' do
        hide_target_tree!

        assert_equal [['related', true]], ccc_for(@tt.id)

        set_hidden_mappings!(false)

        assert_equal [['related', false]], ccc_for(@tt.id)
        assert_includes @content.classification_aliases.map(&:id), @tt.id
      end

      # the same concepts are reachable twice here: through the hidden mapping and as a direct
      # classification (plus its broader ancestor). A direct classification is not "reached through a
      # mapping", so it wins the (thing, relation, concept) row and stays visible.
      test 'a direct classification from a flagged tree stays visible, ancestors included' do
        hide_target_tree!

        @content.set_data_hash(data_hash: { name: 'HiddenMappingProbe', universal_classifications: [@src.primary_classification.id, @tt.primary_classification.id] })
        @content.reload

        assert_equal [['direct', false]], ccc_for(@tt.id)
        assert_equal [['broader', false]], ccc_for(@ttp.id)
        assert_includes @content.classification_aliases.map(&:id), @tt.id
      ensure
        @content.set_data_hash(data_hash: { name: 'HiddenMappingProbe', universal_classifications: [@src.primary_classification.id] })
      end

      test 'a second mapping onto a concept of the flagged tree is hidden too' do
        DataCycleCore::ClassificationGroup.create!(classification: @src2.primary_classification, classification_alias: @tt)
        hide_target_tree!
        @content.set_data_hash(data_hash: { name: 'HiddenMappingProbe', universal_classifications: [@src.primary_classification.id, @src2.primary_classification.id] })
        @content.reload

        assert_equal [['related', true]], ccc_for(@tt.id)
      ensure
        @content.set_data_hash(data_hash: { name: 'HiddenMappingProbe', universal_classifications: [@src.primary_classification.id] })
      end
    end

    # source tree with two leaves (SRC, SRC2) and a target tree TTP -> TT. Content is classified with
    # SRC; a mapping (group on TT pointing at SRC's classification) makes it receive TT + broader TTP.
    def build_hidden_mapping_scenario
      source_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "HiddenSrc_#{SecureRandom.hex(6)}")
      @src = source_tree.create_classification_alias('SRC')
      @src2 = source_tree.create_classification_alias('SRC2')

      @target_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "HiddenTarget_#{SecureRandom.hex(6)}")
      @ttp = @target_tree.create_classification_alias('TTP')
      @tt = @target_tree.create_classification_alias('TTP', 'TT')

      @mapping = DataCycleCore::ClassificationGroup.create!(classification: @src.primary_classification, classification_alias: @tt)

      # through the test-case helper rather than TestPreparations: it drains the jobs the creation
      # enqueues, and the search index the tests read is written by one of them
      @content = create_content('POI', { name: 'HiddenMappingProbe', universal_classifications: [@src.primary_classification.id] })
    end

    def hide_target_tree!
      set_hidden_mappings!(true)
    end

    # The flag is materialised into CCC by ClassificationTreeLabel#refresh_hidden_mappings, which the
    # after_update callback enqueues as a CacheInvalidationJob and which fans the search index and the
    # webhooks out into further jobs — so the whole chain has to be drained before CCC is read.
    def set_hidden_mappings!(hidden_mappings)
      perform_enqueued_jobs { @target_tree.update!(hidden_mappings:) }
      @content.reload
    end

    # the scenario is built once per class, so every test that flags the tree has to hand it back unflagged
    def teardown
      set_hidden_mappings!(false)
      super
    end

    def ccc_for(alias_id)
      @content.collected_classification_contents.where(classification_alias_id: alias_id).pluck(:link_type, :hidden)
    end

    # what the materialised search index holds for the content (Content::UpdateSearch#walk_classifications
    # writes content.classification_aliases into it), not what the association would return now
    def indexed_alias_ids
      DataCycleCore::Search.where(content_data_id: @content.id).pluck(:classification_aliases_mapping).flatten.compact
    end
  end

  # Non-transitive generator (core default).
  class HiddenClassificationMappingsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include HiddenClassificationMappingSharedTests

    before(:all) { build_hidden_mapping_scenario }
  end

  # Transitive generator (enabled e.g. in BayernCloud).
  class HiddenClassificationMappingsTransitiveTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include HiddenClassificationMappingSharedTests

    before(:all) do
      @before_state = DataCycleCore.features[:transitive_classification_path][:enabled]
      DataCycleCore.features[:transitive_classification_path][:enabled] = true
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!

      build_hidden_mapping_scenario
    end

    after(:all) do
      DataCycleCore.features[:transitive_classification_path][:enabled] = @before_state
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!
    end

    # #50677: only the flagged tree is hidden. A mapping that leads *out of* it into an unflagged tree
    # keeps delivering visibly — chaining through a flagged tree does not taint the rest of the path.
    # Transitive-only: the non-transitive generator does not chain mappings at all.
    test 'a mapping out of the flagged tree stays visible' do
      chain_tree = DataCycleCore::ClassificationTreeLabel.create!(name: "HiddenChain_#{SecureRandom.hex(6)}")
      chained = chain_tree.create_classification_alias('CC')
      DataCycleCore::ClassificationGroup.create!(classification: @tt.primary_classification, classification_alias: chained)
      hide_target_tree!

      assert_equal [['related', true]], ccc_for(@tt.id)
      assert_equal [['related', false]], ccc_for(chained.id)

      # chained concepts only ever come from CCC — content.classification_aliases spans a single
      # mapping hop (classification -> classification_groups), so it never contains them
      visible = @content.full_classification_aliases.map(&:id)

      assert_includes visible, chained.id
      assert_not_includes visible, @tt.id
    end
  end
end
