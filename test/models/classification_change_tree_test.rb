# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationChangeTreeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @tags = DataCycleCore::ClassificationTreeLabel.find_by!(name: 'Tags')
      @tags.create_classification_alias('parent 1', 'parent 2', 'child 1')
      @tags.create_classification_alias('parent 1', 'parent 2', 'child 2')
      @tags.create_classification_alias('parent 1', 'parent 2_1')

      @classification = DataCycleCore::ClassificationAlias.for_tree(@tags.name).find_by!(internal_name: 'parent 2')
      @paths = DataCycleCore::ClassificationAlias.for_tree(@tags.name).with_name('parent 2').with_descendants
    end

    test 'move tree to higher level' do
      assert(@paths.reload.map(&:full_path).all? { |p| p.include?('parent 1') })

      @classification.classification_tree.update_column(:parent_classification_alias_id, nil)

      assert(@paths.reload.map(&:full_path).none? { |p| p.include?('parent 1') })
    end

    test 'move tree to lower level' do
      assert(@paths.reload.map(&:full_path).all? { |p| p.include?('parent 1') })

      new_parent = DataCycleCore::ClassificationAlias.for_tree(@tags.name).find_by!(internal_name: 'parent 2_1')

      @classification.classification_tree.update_column(:parent_classification_alias_id, new_parent.id)

      assert(@paths.reload.map(&:full_path).all? { |p| p.include?('parent 2_1') })
    end
  end
end
