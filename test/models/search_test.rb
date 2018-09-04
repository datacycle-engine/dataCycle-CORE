# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

module DataCycleCore
  class SearchTest < ActiveSupport::TestCase
    test 'test search utility functions' do
      template_data = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Bild2')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_data.schema
      data_set.template_name = template_data.template_name
      data_set.save

      data_hash = {
        'caption' => 'Caption Test',
        'comment' => 'Comment Test',
        'description' => 'Description Test',
        'photographer' => 'Photographer Test'
      }
      data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      data_set.set_search
      data_set.save

      assert(1, DataCycleCore::Search.count)
    end
  end
end

describe DataCycleCore::Search do
  def create_content(template_class, template_name, data = {})
    content = template_class.new
    content.schema = template_class.find_by(template: true, template_name: template_name).schema
    content.template_name = template_name
    content.save!

    result = content.set_data_hash(data_hash: data.stringify_keys)
    raise 'InvalidData' if result[:error].present?
    content.save!

    content.set_search
    content.save!

    content
  end

  def find_classification_alias_ids(tree_name, *alias_names)
    DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).pluck(:id)
  end

  def run(*args, &block)
    result = nil

    ActiveRecord::Base.transaction do
      DataCycleCore::TestPreparations.load_classifications([Rails.root.join('..', 'data_types', 'search', 'classifications.yml')])
      DataCycleCore::TestPreparations.load_templates([Rails.root.join('..', 'data_types', 'search')])

      result = super

      raise ActiveRecord::Rollback
    end

    result
  end

  before do
    @contents = [
      create_content(
        DataCycleCore::CreativeWork,
        'Searchable Headline',
        {
          headline: 'HEADLINE 1',
          tag: DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 1')
                                                 .map(&:classifications).flatten.map(&:id)
        }
      ),
      create_content(
        DataCycleCore::CreativeWork,
        'Searchable Headline',
        {
          headline: 'HEADLINE 2',
          tag: DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 2', 'Nested Tag 1')
                                                 .map(&:classifications).flatten.map(&:id)
        }
      ),
      create_content(
        DataCycleCore::CreativeWork,
        'Searchable Headline',
        {
          headline: 'HEADLINE 2',
          tag: DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 1', 'Tag 2')
                                                 .map(&:classifications).flatten.map(&:id)
        }
      )
    ]
  end

  after do
    @contents.each(&:destroy_content).each(&:destroy!)

    @contents = nil
  end

  it 'filters contents based on single classification' do
    DataCycleCore::Search
      .with_classification_aliases(find_classification_alias_ids('Inhaltstypen', 'Searchable Headline'))
      .count.must_equal 3
  end

  it 'filters contents based on multiple classifications' do
    DataCycleCore::Search
      .with_classification_aliases(find_classification_alias_ids('Inhaltstypen', 'Searchable Headline'))
      .with_classification_aliases(find_classification_alias_ids('Tags', 'Tag 1', 'Tag 2'))
      .count.must_equal 3

    DataCycleCore::Search
      .with_classification_aliases(find_classification_alias_ids('Inhaltstypen', 'Searchable Headline'))
      .with_classification_aliases(find_classification_alias_ids('Tags', 'Tag 1'))
      .count.must_equal 2

    DataCycleCore::Search
      .with_classification_aliases(find_classification_alias_ids('Inhaltstypen', 'Searchable Headline'))
      .with_classification_aliases(find_classification_alias_ids('Tags', 'Tag 2'))
      .count.must_equal 2

    DataCycleCore::Search
      .with_classification_aliases(find_classification_alias_ids('Inhaltstypen', 'Searchable Headline'))
      .with_classification_aliases(find_classification_alias_ids('Tags', 'Tag 1'))
      .with_classification_aliases(find_classification_alias_ids('Tags', 'Tag 2'))
      .count.must_equal 1
  end

  it 'filters contents based on nested classifications' do
    DataCycleCore::Search
      .with_classification_aliases(find_classification_alias_ids('Inhaltstypen', 'Searchable Headline'))
      .with_classification_aliases(find_classification_alias_ids('Tags', 'Nested Tag 1'))
      .count.must_equal 1
  end
end
