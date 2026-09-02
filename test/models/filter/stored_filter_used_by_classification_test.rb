# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # #43524: StoredFilter.used_by_classification finds every stored filter that uses a given
  # classification_alias id or classification_tree_label id as a filter criterion - directly, or
  # indirectly through another stored filter that includes it via SELF_REFERENCE_FILTER_TYPES.
  class StoredFilterUsedByClassificationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      @classification_id = DataCycleCore::ClassificationAlias.for_tree('Tags').first.id
    end

    def classification_param(classification_id)
      { 'c' => 'a', 'm' => 'i', 'n' => 'Tags', 't' => 'classification_alias_ids_with_subtree', 'v' => [classification_id] }
    end

    def relation_param(target_id)
      { 'c' => 'a', 'm' => 'i', 'n' => 'rel', 'q' => 'copyright_holder', 't' => 'relation_filter', 'v' => target_id }
    end

    # build a child classification alias under `parent_alias` in the Tags tree, so the path table
    # (which #descendants relies on) is populated by the DB triggers on classification_trees insert.
    def build_child_alias(parent_alias, name)
      tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
      ca = DataCycleCore::ClassificationAlias.new
      I18n.available_locales.each { |l| I18n.with_locale(l) { ca.name = name } }
      ca.save!
      classification = DataCycleCore::Classification.create!(name: ca.internal_name)
      DataCycleCore::ClassificationGroup.create!(classification:, classification_alias: ca)
      DataCycleCore::ClassificationTree.create!(classification_tree_label: tree_label, parent_classification_alias: parent_alias, sub_classification_alias: ca)
      ca.reload
    end

    test 'a stored filter using the classification directly is found as a direct match' do
      direct = DataCycleCore::StoredFilter.create!(name: 'Cov Direct', user_id: @user.id, language: ['de'], parameters: [classification_param(@classification_id)])

      usage = DataCycleCore::StoredFilter.used_by_classification(@classification_id)

      assert_equal({ direct => true }, usage)
    end

    test 'a stored filter referencing a direct match via filter_ids is found as an indirect match' do
      direct = DataCycleCore::StoredFilter.create!(name: 'Cov Direct', user_id: @user.id, language: ['de'], parameters: [classification_param(@classification_id)])
      indirect = DataCycleCore::StoredFilter.create!(name: 'Cov Indirect', user_id: @user.id, language: ['de'], parameters: [relation_param(direct.id)])

      usage = DataCycleCore::StoredFilter.used_by_classification(@classification_id)

      assert_equal({ direct => true, indirect => false }, usage)
    end

    test 'a deeper transitive chain A -> B -> C is resolved, where C is the direct match' do
      filter_c = DataCycleCore::StoredFilter.create!(name: 'Cov C', user_id: @user.id, language: ['de'], parameters: [classification_param(@classification_id)])
      filter_b = DataCycleCore::StoredFilter.create!(name: 'Cov B', user_id: @user.id, language: ['de'], parameters: [relation_param(filter_c.id)])
      filter_a = DataCycleCore::StoredFilter.create!(name: 'Cov A', user_id: @user.id, language: ['de'], parameters: [relation_param(filter_b.id)])

      usage = DataCycleCore::StoredFilter.used_by_classification(@classification_id)

      assert_equal({ filter_c => true, filter_b => false, filter_a => false }, usage)
    end

    test 'a classification that is not used by any stored filter returns an empty result' do
      other_id = DataCycleCore::ClassificationAlias.for_tree('Tags').second.id
      DataCycleCore::StoredFilter.create!(name: 'Cov Unrelated', user_id: @user.id, language: ['de'], parameters: [classification_param(@classification_id)])

      assert_equal({}, DataCycleCore::StoredFilter.used_by_classification(other_id))
    end

    test 'a stored filter referencing a descendant of the classification is found as a direct match' do
      parent = DataCycleCore::ClassificationAlias.find(@classification_id)
      child = build_child_alias(parent, 'Cov Child')
      referencing_child = DataCycleCore::StoredFilter.create!(name: 'Cov Uses Child', user_id: @user.id, language: ['de'], parameters: [classification_param(child.id)])

      usage = DataCycleCore::StoredFilter.used_by_classification(parent.id)

      assert_includes usage.keys, referencing_child
      assert usage[referencing_child], 'a descendant reference counts as a direct match'
    end

    test 'a classification_tree_label id matches stored filters referencing any alias in that tree' do
      tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
      alias_in_tree = tree_label.classification_aliases.first
      referencing_alias = DataCycleCore::StoredFilter.create!(name: 'Cov Uses Tree Alias', user_id: @user.id, language: ['de'], parameters: [classification_param(alias_in_tree.id)])

      usage = DataCycleCore::StoredFilter.used_by_classification(tree_label.id)

      assert_includes usage.keys, referencing_alias
      assert usage[referencing_alias], 'referencing an alias in the tree counts as a direct match'
    end

    test 'a blank id returns an empty result without querying' do
      assert_equal({}, DataCycleCore::StoredFilter.used_by_classification(nil))
      assert_equal({}, DataCycleCore::StoredFilter.used_by_classification(''))
    end

    test 'an unnamed stored filter is excluded from the result even though it matches' do
      unnamed = DataCycleCore::StoredFilter.create!(user_id: @user.id, language: ['de'], parameters: [classification_param(@classification_id)])

      assert_nil unnamed.name
      assert_equal({}, DataCycleCore::StoredFilter.used_by_classification(@classification_id))
    end

    test 'an unnamed hub filter still resolves an indirect chain, even though the hub itself is not in the result' do
      unnamed_hub = DataCycleCore::StoredFilter.create!(user_id: @user.id, language: ['de'], parameters: [classification_param(@classification_id)])
      named_leaf = DataCycleCore::StoredFilter.create!(name: 'Cov Leaf', user_id: @user.id, language: ['de'], parameters: [relation_param(unnamed_hub.id)])

      usage = DataCycleCore::StoredFilter.used_by_classification(@classification_id)

      assert_equal({ named_leaf => false }, usage)
    end

    test 'traversal terminates for a cycle forced directly in the database (bypassing the self-reference validation)' do
      filter_a = DataCycleCore::StoredFilter.create!(name: 'Cov Cycle A', user_id: @user.id, language: ['de'], parameters: [classification_param(@classification_id)])
      filter_b = DataCycleCore::StoredFilter.create!(name: 'Cov Cycle B', user_id: @user.id, language: ['de'], parameters: [relation_param(filter_a.id)])

      # #self_referential? would reject this update through normal means, so the cycle is forced
      # directly at the DB layer to verify the BFS still terminates if one ever occurred.
      filter_a.update_column(:parameters, [classification_param(@classification_id), relation_param(filter_b.id)])

      usage = nil
      assert_nothing_raised { Timeout.timeout(5) { usage = DataCycleCore::StoredFilter.used_by_classification(@classification_id) } }
      assert_equal({ filter_a => true, filter_b => false }, usage)
    end

    # #43524: classification_usage_record backs both classification_usage_target_ids above and the
    # classification-usage chip on the saved-searches page (see StoredFiltersController#saved_searches).
    test 'classification_usage_record resolves a classification_alias id to the alias itself' do
      alias_record = DataCycleCore::ClassificationAlias.for_tree('Tags').first

      assert_equal alias_record, DataCycleCore::StoredFilter.classification_usage_record(alias_record.id)
    end

    test 'classification_usage_record resolves a classification_tree_label id to the tree label itself' do
      tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')

      assert_equal tree_label, DataCycleCore::StoredFilter.classification_usage_record(tree_label.id)
    end

    test 'classification_usage_record returns nil for an id matching neither' do
      assert_nil DataCycleCore::StoredFilter.classification_usage_record(SecureRandom.uuid)
    end
  end
end
