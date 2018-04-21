require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::ClassificationAlias do
  def classification_tree
    @classification_tree ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE')
  end

  after do
    classification_tree.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
    classification_tree.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
    classification_tree.tap(&:reload).classification_aliases.delete_all!
    classification_tree.tap(&:reload).classification_trees.delete_all!
    classification_tree.tap(&:reload).destroy_fully!
    @classification_tree = nil
  end

  it 'should pass on updated name to primary classification' do
    classification_alias = classification_tree.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    classification_alias.name = 'UPDATED NAME'
    classification_alias.save!

    classification_alias.name.must_equal 'UPDATED NAME'
    classification_alias.primary_classification.name.must_equal 'UPDATED NAME'
  end

  describe 'when searching' do
    before do
      classification_tree.create_classification_alias('A')
      classification_tree.create_classification_alias('A', 'A - 1')
      classification_tree.create_classification_alias('A', 'AB - 2')
      classification_tree.create_classification_alias('B')
      classification_tree.create_classification_alias('B', 'BCD - 1')
    end

    it 'should return matching classification aliases' do
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('A').count.must_equal 3
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('b').count.must_equal 3
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('1').count.must_equal 2
      DataCycleCore::ClassificationAlias.for_tree('CLASSIFICATION TREE').search('2').count.must_equal 1
    end
  end
end
