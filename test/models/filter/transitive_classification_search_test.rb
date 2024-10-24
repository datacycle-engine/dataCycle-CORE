# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TransitiveClassificationSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @before_state = DataCycleCore.features[:transitive_classification_path][:enabled]
      DataCycleCore.features[:transitive_classification_path][:enabled] = true
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::RunTaskJob.perform_now('db:configure:rebuild_transitive_tables')

      @tags = DataCycleCore::ClassificationTreeLabel.find_by!(name: 'Tags')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TEST 1 ARTIKEL', tags: DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(@tags.name, 'Tag 1') })

      @tree2 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 2')
      @tree3 = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree 3')
      @dummy_tree = DataCycleCore::ClassificationTreeLabel.create!(name: 'Tree Dummy')
      @tree2.create_classification_alias('parent 1', 'mapped 1')
      @tree2.create_classification_alias('parent 1', 'mapped 1.1')
      @tree3.create_classification_alias('parent 2', 'mapped 2')
      @dummy_tree.create_classification_alias('parent dummy', 'mapped dummy')

      tag1 = DataCycleCore::ClassificationAlias.for_tree(@tags.name).find_by!(internal_name: 'Tag 1')
      tag2 = DataCycleCore::ClassificationAlias.for_tree(@tags.name).find_by!(internal_name: 'Tag 2')
      mapped1 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'mapped 1')
      @mapped12 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'mapped 1.1')
      mapped2 = DataCycleCore::ClassificationAlias.for_tree(@tree3.name).find_by!(internal_name: 'mapped 2')
      parent1 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'parent 1')
      dummy = DataCycleCore::ClassificationAlias.for_tree(@dummy_tree.name).find_by!(internal_name: 'mapped dummy')

      mapped1.update!(classification_ids: [mapped1.primary_classification.id, tag1.primary_classification.id, dummy.primary_classification.id])
      @mapped12.update!(classification_ids: [@mapped12.primary_classification.id, tag2.primary_classification.id])
      mapped2.update!(classification_ids: [mapped2.primary_classification.id, parent1.primary_classification.id])
    end

    after(:all) do
      DataCycleCore.features[:transitive_classification_path][:enabled] = @before_state
      DataCycleCore::Feature::TransitiveClassificationPath.reload
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
      DataCycleCore::RunTaskJob.perform_now('db:configure:rebuild_transitive_tables')
    end

    test 'recursion in mappings works without infinite loop' do
      mapped1 = DataCycleCore::ClassificationAlias.for_tree(@tree2.name).find_by!(internal_name: 'mapped 1')
      mapped2 = DataCycleCore::ClassificationAlias.for_tree(@tree3.name).find_by!(internal_name: 'mapped 2')

      timeout = 10

      ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_for_conditions(['SET LOCAL statement_timeout = ?', timeout * 1000]))
        Timeout.timeout(timeout) do
          mapped1.update!(classification_ids: [mapped1.primary_classification.id, mapped2.primary_classification.id])
          mapped2.update!(classification_ids: [mapped2.primary_classification.id, mapped1.primary_classification.id])
        end
      end
    end

    test 'filter contents based on mapped (2 hops) classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree3.name).with_internal_name('mapped 2').pluck(:id)
      )

      assert_equal(1, items.query.size)
    end

    test 'filter contents based on mapped (1 hop) classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree2.name).with_internal_name('mapped 1').pluck(:id)
      )

      assert_equal(1, items.query.size)
    end

    test 'filter contents based on mapped (2 hops) classifications by id without subtree' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_without_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree3.name).with_internal_name('mapped 2').pluck(:id)
      )
      assert_equal(0, items.query.size)
    end

    test 'filter contents based on mapped (1 hop) classifications by id without subtree' do
      items = DataCycleCore::Filter::Search.new(:de)
      items = items.classification_alias_ids_without_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree2.name).with_internal_name('mapped 1').pluck(:id)
      )

      assert_equal(1, items.query.size)
    end

    test 'filter contents based on mapped (2 hops) classifications, excluding contents with target classification' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree3.name).with_internal_name('mapped 2').pluck(:id)
      ).not_classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tags.name).with_internal_name('Tag 1').pluck(:id)
      )

      assert_equal(0, items.query.size)
    end

    test 'filter contents based on target classification, excluding contents with mapped (2 hops) classifications' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tags.name).with_internal_name('Tag 1').pluck(:id)
      ).not_classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree3.name).with_internal_name('mapped 2').pluck(:id)
      )

      assert_equal(0, items.query.size)
    end

    test 'filter contents based on mapped (1 hop) parent classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree2.name).with_internal_name('parent 1').pluck(:id)
      )

      assert_equal(1, items.query.size)
    end

    test 'filter contents based on mapped (2 hops) parent classifications by id' do
      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree3.name).with_internal_name('parent 2').pluck(:id)
      )

      assert_equal(1, items.query.size)
    end

    test 'filter contents based on mapped (1 hop) parent classifications by id after removing 1 mapping' do
      @mapped12.update!(classification_ids: [@mapped12.primary_classification.id])

      items = DataCycleCore::Filter::Search.new(:de).classification_alias_ids_with_subtree(
        DataCycleCore::ClassificationAlias.for_tree(@tree2.name).with_internal_name('parent 1').pluck(:id)
      )

      assert_equal(1, items.query.size)
    end
  end
end
