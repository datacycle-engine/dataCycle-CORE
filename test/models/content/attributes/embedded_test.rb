# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedTest < ActiveSupport::TestCase
        def setup
          # insert embedded (embedded includes linked)
          @cw_temp = DataCycleCore::Thing.count

          linked = DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'linked'), prevent_history: true)
          linked_id = linked.id
          @linked_objects = [linked_id]

          @data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Creative-Work-1', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge(
            { 'embedded_creative_work' =>
                [
                  DataCycleCore::TestPreparations
                    .load_dummy_data_hash('creative_works', 'embedded')
                    .merge({ 'linked_place' => [linked_id] })
                ] }
          ), prevent_history: true)

          returned_data_hash = @data_set.get_data_hash

          expected_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge(
            { 'embedded_creative_work' =>
                [
                  DataCycleCore::TestPreparations
                    .load_dummy_data_hash('creative_works', 'embedded')
                    .merge({ 'linked_place' => [linked_id] })
                ] }
          )
          assert_equal(0, @data_set.errors.messages.size)
          assert_equal(
            expected_hash.except('embedded_creative_work'),
            returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes)
          )
          assert_equal(
            expected_hash['embedded_creative_work'].first.except('linked_place'),
            returned_data_hash['embedded_creative_work'].first.except('linked_place', *DataCycleCore::TestPreparations.excepted_attributes)
          )
          assert_equal([linked_id], returned_data_hash['embedded_creative_work'].first['linked_place']&.ids)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Linked-Place-1').count)
          assert_equal(2, DataCycleCore::ContentContent.count)
        end

        test 'insert embedded (embedded includes linked) then delete embedded' do
          data_set = @data_set

          # delete embedded
          assert(data_set.has_related?)
          data_hash = data_set.get_data_hash
          data_hash['embedded_creative_work'] = []
          data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash
          expected_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge(
            {
              'embedded_creative_work' => []
            }
          )

          assert_equal(0, data_set.errors.size)
          assert_equal(expected_hash, returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))

          # check consistency of data in DB
          assert_equal(2, DataCycleCore::Thing.where(template: false).count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'insert multiple embedded(embedded includes linked) then delete embedded' do
          data_set = @data_set
          linked_id = @linked_objects.first

          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({
              'embedded_creative_work' => [
                DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({ 'linked_place' => [linked_id] }),
                DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({ 'linked_place' => [linked_id] })
              ]
            }),
            prevent_history: true
          )

          assert(data_set.embedded_creative_work.first.parent_templates.pluck(:template_name).include?(data_set.template_name))

          returned_data_hash = data_set.get_data_hash
          expected_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({
            'embedded_creative_work' => [
              DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({ 'linked_place' => [linked_id] }),
              DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({ 'linked_place' => [linked_id] })
            ]
          })

          assert_equal(0, data_set.errors.size)
          assert_equal(
            expected_hash.except('embedded_creative_work'),
            returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes)
          )
          assert_equal(
            expected_hash['embedded_creative_work'].first.except('linked_place'),
            returned_data_hash['embedded_creative_work'].first.except('linked_place', *DataCycleCore::TestPreparations.excepted_attributes)
          )
          assert_equal([linked_id], returned_data_hash['embedded_creative_work'].first['linked_place'].ids)

          # check consistency of data in DB
          assert_equal(4, DataCycleCore::Thing.where(template: false).count)
          assert_equal(4, DataCycleCore::ContentContent.count)

          assert_equal(
            expected_hash.except('embedded_creative_work'),
            returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes)
          )
          assert_equal(expected_hash['embedded_creative_work'].count, returned_data_hash['embedded_creative_work'].count)

          # delete embedded
          data_hash = data_set.get_data_hash
          data_hash['embedded_creative_work'] = []
          data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash
          expected_hash['embedded_creative_work'] = []
          assert_equal(0, data_set.errors.size)
          assert_equal(expected_hash, returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))

          # check consistency of data in DB
          assert_equal(2, DataCycleCore::Thing.where(template: false).count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'insert embeddedObject, then add another quotation and change order' do
          data_set = @data_set
          linked_id = @linked_objects.first

          data_hash = data_set.get_data_hash
          embedded_creative_work_id = data_hash['embedded_creative_work'][0]['id']
          data_hash['embedded_creative_work'][0]['id'] = embedded_creative_work_id
          data_hash['embedded_creative_work'].push({
            'headline' => 'However beautiful the strategy, you should occasionally look at the results. 2',
            'description' => 'Description goes here juhu! 2',
            'linked_place' => [linked_id]
          })
          data_set.set_data_hash(data_hash: data_hash)
          data_set.save
          returned_data_hash = data_set.get_data_hash

          expected_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({
            'embedded_creative_work' => [
              DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({ 'linked_place' => [linked_id] }),
              DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'embedded').merge({ 'linked_place' => [linked_id] })
            ]
          })

          assert_equal(0, data_set.errors.size)
          assert_equal(
            expected_hash.except('embedded_creative_work'),
            returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes)
          )
          assert_equal(2, returned_data_hash['embedded_creative_work'].count)

          # check consistency of data in DB
          assert_equal(4, DataCycleCore::Thing.where(template: false).count)
          assert_equal(4, DataCycleCore::ContentContent.count)

          data_hash['embedded_creative_work'].reverse!
          expected_hash['embedded_creative_work'].reverse!
          data_set.set_data_hash(data_hash: data_hash)
          returned_data_hash = data_set.get_data_hash

          assert data_set.errors.blank?
          assert_equal(
            expected_hash.except('embedded_creative_work'),
            returned_data_hash.compact.except('embedded_creative_work', *DataCycleCore::TestPreparations.excepted_attributes)
          )
          assert_equal(2, returned_data_hash['embedded_creative_work'].count)

          # check consistency of data in DB
          assert_equal(4, DataCycleCore::Thing.where(template: false).count)
          assert_equal(2, data_set.content_content_a.where(relation_a: 'embedded_creative_work').size)
        end
      end
    end
  end
end
