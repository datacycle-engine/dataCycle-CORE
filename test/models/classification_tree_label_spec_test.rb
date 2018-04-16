require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::ClassificationTreeLabel do
  def tree_one
    @tree_one ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE I')
  end

  def tree_two
    @tree_two ||= DataCycleCore::ClassificationTreeLabel.create!(name: 'CLASSIFICATION TREE II')
  end

  def external_source
    @external_source ||= DataCycleCore::ExternalSource.create!(name: 'DUMMY SOURCE')
  end

  after do
    tree_one.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
    tree_one.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
    tree_one.tap(&:reload).classification_aliases.delete_all!
    tree_one.tap(&:reload).classification_trees.delete_all!
    tree_one.tap(&:reload).destroy_fully!
    @tree_one = nil

    tree_two.tap(&:reload).classification_aliases.map(&:classifications).each(&:delete_all!)
    tree_two.tap(&:reload).classification_aliases.map(&:classification_groups).each(&:delete_all!)
    tree_two.tap(&:reload).classification_aliases.delete_all!
    tree_two.tap(&:reload).classification_trees.delete_all!
    tree_two.tap(&:reload).destroy_fully!
    @tree_two = nil

    external_source.delete
    @external_source = nil
  end

  it 'should create necessary objects for classifications' do
    tree_one.create_classification_alias('CLASSIFICATION 1')

    tree_one.classification_aliases.size.must_equal 1
    tree_one.classification_aliases.first.name.must_equal 'CLASSIFICATION 1'

    tree_one.classification_aliases.first.classifications.size.must_equal 1
    tree_one.classification_aliases.first.classifications.first.name.must_equal 'CLASSIFICATION 1'
  end

  it 'should create necessary objects for nested classifications' do
    tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A', 'CLASSIFICATION I - A - 1')

    classification_aliases = tree_one.classification_aliases.roots
    classification_aliases.size.must_equal 1
    classification_aliases.first.name.must_equal 'CLASSIFICATION I'

    classification_aliases.first.classifications.size.must_equal 1
    classification_aliases.first.classifications.first.name.must_equal 'CLASSIFICATION I'

    classification_aliases = classification_aliases.first.sub_classification_alias
    classification_aliases.size.must_equal 1
    classification_aliases.first.name.must_equal 'CLASSIFICATION I - A'

    classification_aliases.first.classifications.size.must_equal 1
    classification_aliases.first.classifications.first.name.must_equal 'CLASSIFICATION I - A'

    classification_aliases = classification_aliases.first.sub_classification_alias
    classification_aliases.size.must_equal 1
    classification_aliases.first.name.must_equal 'CLASSIFICATION I - A - 1'

    classification_aliases.first.classifications.size.must_equal 1
    classification_aliases.first.classifications.first.name.must_equal 'CLASSIFICATION I - A - 1'
  end

  it 'should create nested classifications with external sources and keys' do
    classification_attributes = {
      name: 'CLASSIFICATION 1',
      external_source: external_source,
      external_key: '1234'
    }
    tree_one.create_classification_alias(classification_attributes)

    tree_one.classification_aliases.size.must_equal 1
    tree_one.classification_aliases.first.name.must_equal 'CLASSIFICATION 1'
    tree_one.classification_aliases.first.external_source_id.must_equal external_source.id

    tree_one.classification_aliases.first.classifications.size.must_equal 1
    tree_one.classification_aliases.first.classifications.first.name.must_equal 'CLASSIFICATION 1'
    tree_one.classification_aliases.first.classifications.first.external_source_id.must_equal external_source.id
    tree_one.classification_aliases.first.classifications.first.external_key.must_equal '1234'
  end

  it 'should created nested classifications with same name' do
    tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I')

    classification_aliases = tree_one.classification_aliases.roots
    classification_aliases.size.must_equal 1
    classification_aliases.first.name.must_equal 'CLASSIFICATION I'

    classification_aliases.first.classifications.size.must_equal 1
    classification_aliases.first.classifications.first.name.must_equal 'CLASSIFICATION I'

    classification_aliases = classification_aliases.first.sub_classification_alias
    classification_aliases.size.must_equal 1
    classification_aliases.first.name.must_equal 'CLASSIFICATION I'

    classification_aliases.first.classifications.size.must_equal 1
    classification_aliases.first.classifications.first.name.must_equal 'CLASSIFICATION I'
  end

  it 'should ignore aliases from different classification trees' do
    tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')
    tree_two.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    tree_one.classification_aliases.size.must_equal 2
    tree_two.classification_aliases.size.must_equal 2
    tree_one.classification_aliases.each do |tree_one_alias|
      tree_two.classification_aliases.map(&:id).wont_include tree_one_alias.id
    end
  end

  it 'should return newly created alias' do
    classification_alias = tree_one.create_classification_alias('CLASSIFICATION I', 'CLASSIFICATION I - A')

    classification_alias.wont_be_nil
    classification_alias.new_record?.must_equal false
    classification_alias.name.must_equal 'CLASSIFICATION I - A'
  end
end
