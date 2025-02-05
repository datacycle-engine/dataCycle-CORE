# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Concepts::ConceptImporter do
  include DataCycleCore::MinitestSpecHelper

  before do
    importer = DataCycleCore::MasterData::Concepts::ConceptImporter.new(paths: ['test/fixtures/classifications/examples/'])
    importer.import
  end

  def load_single_category(*names)
    categories = DataCycleCore::ClassificationAlias.from_tree(names.first)
    assert_not_nil(categories)
    assert(categories.size.positive?)

    categories.find { |category| category.full_path == names.join(' > ') }
  end

  it 'imports basic categories correctly' do
    category = load_single_category('Basic Categories', 'Basic Subcategory 1.1')
    assert_not_nil(category)
    assert_nil(category.description)
    assert_nil(category.uri)
    assert(category.assignable)
    assert_not(category.internal)

    category = load_single_category('Basic Categories', 'Basic Subcategory 1.2')
    assert_not_nil(category)
    assert_nil(category.description)
    assert_nil(category.uri)
    assert(category.assignable)
    assert_not(category.internal)

    category = load_single_category('Basic Categories', 'Basic Subcategory 1.2', 'Basic Sub-subcategory 1.2.1')
    assert_not_nil(category)
    assert_nil(category.description)
    assert_nil(category.uri)
    assert(category.assignable)
    assert_not(category.internal)

    category = load_single_category('Basic Categories', 'Basic Subcategory 1.2', 'Basic Sub-subcategory 1.2.2')
    assert_not_nil(category)
    assert_nil(category.description)
    assert_nil(category.uri)
    assert(category.assignable)
    assert_not(category.internal)
  end

  it 'validates descriptive categories' do
    category = load_single_category('Descriptive Categories', 'Descriptive Subcategory 1.1')
    assert_not_nil category
    assert_equal 'Description for subcategory 1.1', category.description
    assert_nil category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Descriptive Categories', 'Descriptive Subcategory 1.2')
    assert_not_nil category
    assert_equal 'Description for subcategory 1.2', category.description
    assert_nil category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Descriptive Categories', 'Descriptive Subcategory 1.2', 'Descriptive Sub-subcategory 1.2.1')
    assert_not_nil category
    assert_equal 'Description for sub-subcategory 1.2.1', category.description
    assert_nil category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Descriptive Categories', 'Descriptive Subcategory 1.2', 'Descriptive Sub-subcategory 1.2.2')
    assert_not_nil category
    assert_equal 'Description for sub-subcategory 1.2.2', category.description
    assert_nil category.uri
    assert category.assignable
    assert_not category.internal
  end

  it 'validates internal categories' do
    category = load_single_category('Internal Categories', 'Internal Subcategory 1.1')
    assert_not_nil category
    assert_nil category.description
    assert_nil category.uri
    assert category.assignable
    assert category.internal

    category = load_single_category('Internal Categories', 'Internal Subcategory 1.2')
    assert_not_nil category
    assert_nil category.description
    assert_nil category.uri
    assert category.assignable
    assert category.internal

    category = load_single_category('Internal Categories', 'Internal Subcategory 1.2', 'Internal Sub-subcategory 1.2.1')
    assert_not_nil category
    assert_nil category.description
    assert_nil category.uri
    assert category.assignable
    assert category.internal

    category = load_single_category('Internal Categories', 'Internal Subcategory 1.2', 'Internal Sub-subcategory 1.2.2')
    assert_not_nil category
    assert_nil category.description
    assert_nil category.uri
    assert category.assignable
    assert category.internal
  end

  it 'validates categories with URI' do
    category = load_single_category('Categories with URI', 'URI Subcategory 1.1')
    assert_not_nil category
    assert_nil category.description
    assert_equal 'http://example.com/subcategory1.1', category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Categories with URI', 'URI Subcategory 1.2')
    assert_not_nil category
    assert_nil category.description
    assert_equal 'http://example.com/subcategory1.2', category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Categories with URI', 'URI Subcategory 1.2', 'URI Sub-subcategory 1.2.1')
    assert_not_nil category
    assert_nil category.description
    assert_equal 'http://example.com/sub-subcategory1.2.1', category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Categories with URI', 'URI Subcategory 1.2', 'URI Sub-subcategory 1.2.2')
    assert_not_nil category
    assert_nil category.description
    assert_equal 'http://example.com/sub-subcategory1.2.2', category.uri
    assert category.assignable
    assert_not category.internal
  end

  it 'validates mixed categories' do
    category = load_single_category('Mixed Categories', 'Internal Mixed Subcategory 1.1')
    assert_not_nil category
    assert_equal 'Internal description', category.description
    assert_equal 'http://example.com/internal_subcategory1.1', category.uri
    assert category.assignable
    assert category.internal

    category = load_single_category('Mixed Categories', 'Mixed Subcategory 1.2')
    assert_not_nil category
    assert_equal 'Description for subcategory 1.2', category.description
    assert_equal 'http://example.com/subcategory1.2', category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Mixed Categories', 'Mixed Subcategory 1.2', 'Internal Mixed Sub-subcategory 1.2.1')
    assert_not_nil category
    assert_equal 'Internal description', category.description
    assert_nil category.uri
    assert category.assignable
    assert category.internal

    category = load_single_category('Mixed Categories', 'Mixed Subcategory 1.2', 'Mixed Sub-subcategory 1.2.2')
    assert_not_nil category
    assert_equal 'Description for sub-subcategory 1.2.2', category.description
    assert_equal 'http://example.com/sub-subcategory1.2.2', category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Mixed Categories', 'Internal Mixed Subcategory 1.3')
    assert_not_nil category
    assert_equal 'Another description', category.description
    assert_equal 'http://example.com/subcategory1.3', category.uri
    assert category.assignable
    assert category.internal

    category = load_single_category('Mixed Categories', 'Internal Mixed Subcategory 1.3', 'Mixed Sub-subcategory 1.3.1')
    assert_not_nil category
    assert_equal 'Another sub-description', category.description
    assert_equal 'http://example.com/sub-subcategory1.3.1', category.uri
    assert category.assignable
    assert_not category.internal

    category = load_single_category('Mixed Categories', 'Internal Mixed Subcategory 1.3', 'Internal Mixed Sub-subcategory 1.3.2')
    assert_not_nil category
    assert_equal 'Internal sub-description', category.description
    assert_equal 'http://example.com/internal_sub-subcategory1.3.2', category.uri
    assert category.assignable
    assert category.internal
  end
end
