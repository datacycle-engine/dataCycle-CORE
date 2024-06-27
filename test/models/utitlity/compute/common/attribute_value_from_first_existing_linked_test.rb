# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AttributeValueFromFirstExistingLinkedTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @linked_content = TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { name: 'linked-place-1 test' })
      file_name = 'test_rgb.jpeg'
      @image = upload_image(file_name)
      @collection = WatchList.create(name: 'test-watchlist')
      @tag1 = Concept.for_tree('Tags').first
      @start_time = Time.zone.now
      @end_time = Time.zone.now + 1.day + 1.hour
      @schedule_value = [Schedule.transform_data_for_data_hash({
        start_time: { time: @start_time, zone: @start_time.time_zone.name },
        end_time: { time: @start_time + 1.hour, zone: @start_time.time_zone.name},
        rrules: [{ rule_type: 'IceCube::DailyRule', until: @end_time, interval: 1}],
        duration: 'PT1H',
        rtimes: nil,
        extimes: nil
      }.with_indifferent_access)]
      @new_content = TestPreparations.create_content(template_name: 'Computed-Common-attribute_value_from_first_existing_linked', data_hash: { name: 'test organization' })
      @content1 = TestPreparations.create_content(
        template_name: 'Computed-Common-attribute_value_from_first_existing_linked',
        data_hash: {
          name: 'test',
          translated_string_value: 'test de',
          linked_value: [@linked_content.id],
          embedded_value: [{ name: 'embedded test', embedded_sub_value: [{ name: 'sub embedded test' }] }],
          translated_embedded_value: [{ name: 'embedded test de', embedded_sub_value: [{ name: 'sub embedded test de' }] }],
          date_value: Time.zone.today.to_date,
          datetime_value: DateTime.now,
          boolean_value: true,
          geographic_value: 'POINT (14.04813 46.86031)',
          slug_value: 'slug-value',
          number_value: 1,
          schedule_value: @schedule_value,
          classification_value: [@tag1.classification_id],
          asset_value: @image.id,
          collection_value: [@collection.id]
        }
      )

      @content2 = TestPreparations.create_content(
        template_name: 'Computed-Common-attribute_value_from_first_existing_linked',
        data_hash: {
          name: 'test 2',
          translated_string_value: 'test de 2'
        }
      )

      @content3 = TestPreparations.create_content(
        template_name: 'Computed-Common-attribute_value_from_first_existing_linked',
        data_hash: {
          name: 'test 3',
          boolean_value: false
        }
      )
    end

    def subject_method(attribute, override_parameters, parameters)
      DataCycleCore::Utility::Compute::Common.attribute_value_from_first_existing_linked(
        content: @new_content,
        key: attribute,
        computed_definition: {
          'compute' => {
            'parameters' => [
              "value_aggregate_for_override.#{attribute}",
              "aggregate_for.#{attribute}"
            ]
          }
        }, computed_parameters: {
          'value_aggregate_for_override' => override_parameters,
          'aggregate_for' => parameters
        }
      )
    end

    test 'return name from first linked, if present?' do
      key = 'name'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content2.send(key), value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content3.send(key), value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content2.send(key), value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content3.send(key), value)
    end

    test 'return translated_string_value from first linked, if present?' do
      key = 'translated_string_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content2.send(key), value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content2.send(key), value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)
    end

    test 'return date_value from first linked, if present?' do
      key = 'date_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)
    end

    test 'return boolean_value from first linked, if present?' do
      key = 'boolean_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content3.send(key), value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content3.send(key), value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content3.send(key), value)
    end

    test 'return geographic_value from first linked, if present?' do
      key = 'geographic_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).to_s, value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)
    end

    test 'return slug_value from first linked, if present?' do
      key = 'slug_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content2.send(key), value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content3.send(key), value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content2.send(key), value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content3.send(key), value)
    end

    test 'return number_value from first linked, if present?' do
      key = 'number_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key), value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)
    end

    test 'return classification_value from first linked, if present?' do
      key = 'classification_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)
    end

    test 'return asset_value from first linked, if present?' do
      key = 'asset_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).id, value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content1.send(key).id, value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key).id, value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).id, value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_nil(value)
    end

    test 'return collection_value from first linked, if present?' do
      key = 'collection_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, nil, [@content3.id, @content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, nil, [@content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id])
      assert_equal(@content1.send(key).pluck(:id), value)

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)
    end

    test 'return schedule_value from first linked, if present?' do
      key = 'schedule_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['start_time'], value['start_time'])
      assert_equal("#{@new_content.id}_#{key}_#{orig_value['id']}", value['external_key'])
      assert_nil(value['id'])

      @new_content.set_data_hash(data_hash: { key => [value]})

      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['start_time'], value['start_time'])
      assert_equal("#{@new_content.id}_#{key}_#{orig_value['id']}", value['external_key'])
      assert_equal(@new_content.try(key).first.id, value['id'])

      value = subject_method(key, nil, [@content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['start_time'], value['start_time'])

      value = subject_method(key, nil, [@content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['start_time'], value['start_time'])

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['start_time'], value['start_time'])

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)
    end

    test 'return translated_embedded_value from first linked, if present?' do
      key = 'translated_embedded_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])
      assert_equal("#{@new_content.id}_#{key}_#{orig_value['id']}", value['external_key'])
      assert_nil(value['id'])

      @new_content.set_data_hash(data_hash: { key => [value]})

      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])
      assert_equal("#{@new_content.id}_#{key}_#{orig_value['id']}", value['external_key'])
      assert_equal(@new_content.try(key).first.id, value['id'])
      assert_equal(@new_content.try(key).first.embedded_sub_value.first.id, value.dig('embedded_sub_value', 0, 'id'))
      assert_equal("#{@new_content.id}_#{key}_#{orig_value['id']}_embedded_sub_value_#{orig_value.dig('embedded_sub_value', 0, 'id')}", value.dig('embedded_sub_value', 0, 'external_key'))

      value = subject_method(key, nil, [@content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])

      value = subject_method(key, nil, [@content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)
    end

    test 'return embedded_value from first linked, if present?' do
      key = 'embedded_value'
      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])
      assert_equal("#{@new_content.id}_de_#{key}_#{orig_value['id']}", value['external_key'])
      assert_nil(value['id'])

      @new_content.set_data_hash(data_hash: { key => [value]})

      value = subject_method(key, nil, [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])
      assert_equal("#{@new_content.id}_de_#{key}_#{orig_value['id']}", value['external_key'])
      assert_equal(@new_content.try(key).first.id, value['id'])
      assert_equal(@new_content.try(key).first.embedded_sub_value.first.id, value.dig('embedded_sub_value', 0, 'id'))
      assert_equal("#{@new_content.id}_de_#{key}_#{orig_value['id']}_embedded_sub_value_#{orig_value.dig('embedded_sub_value', 0, 'id')}", value.dig('embedded_sub_value', 0, 'external_key'))

      value = subject_method(key, nil, [@content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])

      value = subject_method(key, nil, [@content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])

      value = subject_method(key, [@content1.id], [@content2.id, @content3.id, @content1.id]).first
      orig_value = @content1.send(key).first.to_h.with_indifferent_access
      assert_equal(orig_value['name'], value['name'])

      value = subject_method(key, [@content2.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)

      value = subject_method(key, [@content3.id], [@content2.id, @content3.id, @content1.id])
      assert_empty(value)
    end
  end
end
