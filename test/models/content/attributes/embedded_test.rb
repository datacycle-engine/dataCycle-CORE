# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedTest < ActiveSupport::TestCase
        test 'CreativeWork exists' do
          data = DataCycleCore::CreativeWork.new
          assert_equal(data.class, DataCycleCore::CreativeWork)
        end

        test 'insert embedded within same table (embedded includes linked from other table)' do
          template_embedded_entity = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Embedded-Entity-Creative-Work-1')
          template_linked_entity = DataCycleCore::Place.find_by(template: true, template_name: 'Linked-Place-1')

          # create linked entity
          linked = DataCycleCore::Place.new
          linked.schema = template_linked_entity.schema
          linked.template_name = template_linked_entity.template_name
          linked.save
          linked.set_data_hash(data_hash: { 'headline' => 'Linked Entity', 'description' => 'Description Linked Entity' }, prevent_history: true)
          linked.save
          linked_id = linked.id

          # create an Article
          data_set = DataCycleCore::CreativeWork.new
          data_set.schema = template_embedded_entity.schema
          data_set.template_name = template_embedded_entity.template_name
          data_set.save
          data_hash = {
            'headline' => 'Dies ist ein Test!',
            'description' => 'wtf is going on???',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              }
            ]
          }
          error = data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash

          expected_hash = {
            'description' => 'wtf is going on???',
            'headline' => 'Dies ist ein Test!',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              }
            ]
          }
          assert_equal(0, error[:error].count)
          assert_equal(expected_hash.except('embedded_creative_work'), returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(expected_hash['embedded_creative_work'].first.except('linked_place'), returned_data_hash['embedded_creative_work'].first.except('linked_place', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal([linked_id], returned_data_hash['embedded_creative_work'].first['linked_place'].ids)

          # check consistency of data in DB
          assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
          assert_equal(2, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Place.where(template: false).count)
        end

        test 'insert embedded within same table (embedded includes linked from other table) then delete embedded' do
          # quotation is embedded --> should be deleted
          # author within quotation is linked --> only link should be deleted

          template_embedded_entity = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Embedded-Entity-Creative-Work-1')
          template_linked_entity = DataCycleCore::Place.find_by(template: true, template_name: 'Linked-Place-1')

          # create linked entity
          linked = DataCycleCore::Place.new
          linked.schema = template_linked_entity.schema
          linked.template_name = template_linked_entity.template_name
          linked.save
          linked.set_data_hash(data_hash: { 'headline' => 'Linked Entity', 'description' => 'Description Linked Entity' }, prevent_history: true)
          linked.save
          linked_id = linked.id

          # create an Article
          data_set = DataCycleCore::CreativeWork.new
          data_set.schema = template_embedded_entity.schema
          data_set.template_name = template_embedded_entity.template_name
          data_set.save
          data_hash = {
            'headline' => 'Dies ist ein Test!',
            'description' => 'wtf is going on???',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              }
            ]
          }
          error = data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash

          expected_hash = {
            'description' => 'wtf is going on???',
            'headline' => 'Dies ist ein Test!',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              }
            ]
          }
          assert_equal(0, error[:error].count)
          assert_equal(expected_hash.except('embedded_creative_work'), returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(expected_hash['embedded_creative_work'].first.except('linked_place'), returned_data_hash['embedded_creative_work'].first.except('linked_place', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal([linked_id], returned_data_hash['embedded_creative_work'].first['linked_place'].ids)

          # check consistency of data in DB
          assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
          assert_equal(2, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Place.where(template: false).count)

          # delete embedded
          data_hash['embedded_creative_work'] = []
          error = data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash
          expected_hash['embedded_creative_work'] = []

          assert_equal(0, error[:error].count)
          assert_equal(expected_hash, returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Place.where(template: false).count)
        end

        test 'insert multiple embedded within same table (embedded includes linked from other table) then delete embedded' do
          # quotation is embedded --> should be deleted
          # author within quotation is linked --> only link should be deleted

          template_embedded_entity = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Embedded-Entity-Creative-Work-1')
          template_linked_entity = DataCycleCore::Place.find_by(template: true, template_name: 'Linked-Place-1')

          # create linked entity
          linked = DataCycleCore::Place.new
          linked.schema = template_linked_entity.schema
          linked.template_name = template_linked_entity.template_name
          linked.save
          linked.set_data_hash(data_hash: { 'headline' => 'Linked Entity', 'description' => 'Description Linked Entity' }, prevent_history: true)
          linked.save
          linked_id = linked.id

          # create an Article
          data_set = DataCycleCore::CreativeWork.new
          data_set.schema = template_embedded_entity.schema
          data_set.template_name = template_embedded_entity.template_name
          data_set.save
          data_hash = {
            'headline' => 'Dies ist ein Test!',
            'description' => 'wtf is going on???',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              },
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results. 2',
                'description' => 'Description goes here juhu! 2',
                'linked_place' => [linked_id]
              }
            ]
          }
          error = data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash

          expected_hash = {
            'description' => 'wtf is going on???',
            'headline' => 'Dies ist ein Test!',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              },
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results. 2',
                'description' => 'Description goes here juhu! 2',
                'linked_place' => [linked_id]
              }
            ]
          }
          assert_equal(0, error[:error].count)
          assert_equal(expected_hash.except('embedded_creative_work'), returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(expected_hash['embedded_creative_work'].first.except('linked_place'), returned_data_hash['embedded_creative_work'].first.except('linked_place', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal([linked_id], returned_data_hash['embedded_creative_work'].first['linked_place'].ids)

          # check consistency of data in DB
          assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
          assert_equal(4, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Place.where(template: false).count)

          assert_equal(0, error[:error].count)
          assert_equal(expected_hash.except('embedded_creative_work'), returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(expected_hash['embedded_creative_work'].count, returned_data_hash['embedded_creative_work'].count)

          # delete embedded
          data_hash['embedded_creative_work'] = []
          error = data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash
          expected_hash['embedded_creative_work'] = []
          assert_equal(0, error[:error].count)
          assert_equal(expected_hash, returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Place.where(template: false).count)
        end

        test 'insert embeddedObject within same table then add another quotation' do
          template_embedded_entity = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Embedded-Entity-Creative-Work-1')
          template_linked_entity = DataCycleCore::Place.find_by(template: true, template_name: 'Linked-Place-1')

          # create linked entity
          linked = DataCycleCore::Place.new
          linked.schema = template_linked_entity.schema
          linked.template_name = template_linked_entity.template_name
          linked.save
          linked.set_data_hash(data_hash: { 'headline' => 'Linked Entity', 'description' => 'Description Linked Entity' }, prevent_history: true)
          linked.save
          linked_id = linked.id

          # create an Article
          data_set = DataCycleCore::CreativeWork.new
          data_set.schema = template_embedded_entity.schema
          data_set.template_name = template_embedded_entity.template_name
          data_set.save
          data_hash = {
            'headline' => 'Dies ist ein Test!',
            'description' => 'wtf is going on???',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              }
            ]
          }
          error = data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash

          expected_hash = {
            'description' => 'wtf is going on???',
            'headline' => 'Dies ist ein Test!',
            'embedded_creative_work' => [
              {
                'headline' => 'However beautiful the strategy, you should occasionally look at the results.',
                'description' => 'Description goes here juhu!',
                'linked_place' => [linked_id]
              }
            ]
          }
          assert_equal(0, error[:error].count)
          assert_equal(expected_hash.except('embedded_creative_work'), returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(expected_hash['embedded_creative_work'].first.except('linked_place'), returned_data_hash['embedded_creative_work'].first.except('linked_place', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal([linked_id], returned_data_hash['embedded_creative_work'].first['linked_place'].ids)

          # check consistency of data in DB
          assert_equal(2, DataCycleCore::CreativeWork.where(template: false).count)
          assert_equal(2, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Place.where(template: false).count)

          embedded_creative_work_id = returned_data_hash['embedded_creative_work'][0]['id']
          data_hash['embedded_creative_work'][0]['id'] = embedded_creative_work_id
          data_hash['embedded_creative_work'].push(
            {
              'headline' => 'However beautiful the strategy, you should occasionally look at the results. 2',
              'description' => 'Description goes here juhu! 2',
              'linked_place' => [linked_id]
            }
          )
          error = data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash

          assert_equal(0, error[:error].count)
          assert_equal(expected_hash.except('embedded_creative_work'), returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes))
          assert_equal(2, returned_data_hash['embedded_creative_work'].count)

          # check consistency of data in DB
          assert_equal(3, DataCycleCore::CreativeWork.where(template: false).count)
          assert_equal(4, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Place.where(template: false).count)
        end
      end
    end
  end
end
