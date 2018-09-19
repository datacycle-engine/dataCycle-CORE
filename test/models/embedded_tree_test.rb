# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedTreeTest < ActiveSupport::TestCase
    def excepted_attributes
      ['id', 'data_pool', 'data_type', 'last_updated_by', 'deleted_by', 'date_modified', 'publication_schedule', 'textblock']
    end
    test 'CreativeWork exists' do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end

    test 'insert embeddedObject within same table' do
      # create an author
      template = DataCycleCore::Person.find_by(template: true, template_name: 'Person')
      data_set = DataCycleCore::Person.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      person_hash = {
        'given_name' => 'Winston',
        'family_name' => 'Churchill'
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where('classification_tree_labels.name = ?', 'Inhaltstypen')
        .where('classification_aliases.name = ?', 'Zitat').first.id

      # create an Article
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'text' => 'wtf is going on???',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'author' => [person_id],
          'data_type' => [data_type_zitat_id]
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        'image' => [],
        'text' => 'wtf is going on???',
        'creator' => [],
        'headline' => 'Dies ist ein Test!',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'image' => [],
          'author' => [person_id]
        }],
        'output_channel' => [],
        'content_location' => [],
        'tags' => []
      }
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except('quotation'), returned_data_hash.compact.except('quotation', *excepted_attributes))
      assert_equal(expected_hash['quotation'].first.except('author'), returned_data_hash['quotation'].first.except('author', *excepted_attributes))
      assert_equal([person_id], returned_data_hash['quotation'].first['author'].ids)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end

    test 'insert quotation, then delete quotation' do
      # quotation is embedded --> should be deleted
      # author within quotation is linked --> only link should be deleted

      # create an author
      template = DataCycleCore::Person.find_by(template: true, template_name: 'Person')
      data_set = DataCycleCore::Person.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      person_hash = {
        'given_name' => 'Winston',
        'family_name' => 'Churchill'
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where('classification_tree_labels.name = ?', 'Inhaltstypen')
        .where('classification_aliases.name = ?', 'Zitat').first.id

      # create an Article
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'text' => 'wtf is going on???',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'author' => [person_id],
          'data_type' => [data_type_zitat_id]
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        'tags' => [],
        'image' => [],
        'text' => 'wtf is going on???',
        'creator' => [],
        'headline' => 'Dies ist ein Test!',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'image' => [],
          'author' => [person_id]
        }],
        'output_channel' => [],
        'content_location' => [],
      }
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except('quotation'), returned_data_hash.compact.except('quotation', *excepted_attributes))
      assert_equal(expected_hash['quotation'].first.except('author'), returned_data_hash['quotation'].first.except('author', *excepted_attributes))
      assert_equal([person_id], returned_data_hash['quotation'].first['author'].ids)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
      assert_equal(3, DataCycleCore::ClassificationContent.count)

      # delete quotation
      data_hash['quotation'] = []
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash['quotation'] = []

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except(*excepted_attributes))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
    end

    test 'insert quotations, then delete quotations' do
      # quotation (embedded) is attached --> should be deletable
      # author within quotation is linked --> only link should be deleted

      # create an author
      template = DataCycleCore::Person.find_by(template: true, template_name: 'Person')
      data_set = DataCycleCore::Person.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      person_hash = {
        'given_name' => 'Winston',
        'family_name' => 'Churchill'
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      # create an Article
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'text' => 'wtf is going on???',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'author' => [person_id]
        }, {
          'text' => 'Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.',
          'author' => [person_id]
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      expected_hash = {
        'tags' => [],
        'image' => [],
        'text' => 'wtf is going on???',
        'creator' => [],
        'headline' => 'Dies ist ein Test!',
        'output_channel' => [],
        'content_location' => [],
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'image' => [],
          'author' => [{
            'id' => person_id,
            'job_title' => nil,
            'given_name' => 'Winston',
            'family_name' => 'Churchill'
          }]
        }, {
          'text' => 'Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.',
          'image' => nil,
          'author' => [{
            'id' => person_id,
            'job_title' => nil,
            'given_name' => 'Winston',
            'family_name' => 'Churchill'
          }]
        }]
      }

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except('quotation', 'data_type'), returned_data_hash.compact.except('quotation', *excepted_attributes))
      assert_equal(expected_hash['quotation'].count, returned_data_hash['quotation'].count)

      # check consistency of data in DB
      assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(4, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)

      # delete quotation
      data_hash['quotation'] = []
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash['quotation'] = []
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash, returned_data_hash.compact.except(*excepted_attributes))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end

    test 'insert embeddedObject within same table then add another quotation' do
      # create an author
      template = DataCycleCore::Person.find_by(template: true, template_name: 'Person')
      data_set = DataCycleCore::Person.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      person_hash = {
        'given_name' => 'Winston',
        'family_name' => 'Churchill'
      }
      data_set.set_data_hash(data_hash: person_hash)
      data_set.save
      person_id = data_set.id

      data_type_zitat_id = DataCycleCore::Classification.joins(classification_aliases: [classification_tree: [:classification_tree_label]])
        .where('classification_tree_labels.name = ?', 'Inhaltstypen')
        .where('classification_aliases.name = ?', 'Zitat').first.id

      # create an Article
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'text' => 'wtf is going on???',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'author' => [person_id]
        }]
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      quotation_id = returned_data_hash['quotation'][0]['id']

      expected_hash = {
        'tags' => [],
        'image' => [],
        'text' => 'wtf is going on???',
        'creator' => [],
        'headline' => 'Dies ist ein Test!',
        'quotation' => [{
          'text' => 'However beautiful the strategy, you should occasionally look at the results.',
          'image' => [],
          'author' => [{
            'id' => person_id,
            'job_title' => nil,
            'given_name' => 'Winston',
            'family_name' => 'Churchill'
          }]
        }],
        'output_channel' => [],
        'content_location' => [],
      }
      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except('quotation'), returned_data_hash.compact.except('quotation', *excepted_attributes))
      assert_equal(expected_hash['quotation'].first.except('author'), returned_data_hash['quotation'].first.except('author', *excepted_attributes))
      assert_equal([person_id], returned_data_hash['quotation'].first['author'].ids)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)

      data_hash['quotation'][0]['id'] = quotation_id
      data_hash['quotation'].push(
        {
          'text' => 'Men occasionally stumble over the truth, but most of them pick themselves up and hurry off as if nothing ever happened.',
          'author' => [person_id]
        }
      )
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash.except('quotation'), returned_data_hash.compact.except('quotation', *excepted_attributes))
      assert_equal(2, returned_data_hash['quotation'].count)

      # check consistency of data in DB
      assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(4, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Person.where(template: false).count)
    end
  end
end
