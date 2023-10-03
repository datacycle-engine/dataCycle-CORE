# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

module SharedExamplesForContent
  def self.for_properties(storage_location)
    describe "for properties with storage location '#{storage_location}'" do
      data_definition = {
        properties: {
          property: {
            label: 'property',
            type: 'string',
            storage_location: storage_location
          },
          existing_property: {
            label: 'existing property',
            type: 'string',
            storage_location: storage_location
          }
        }
      }

      property_value = yield

      subject do
        convert_storage_location = { 'value' => 'metadata', 'translated_value' => 'content' }
        DataCycleCore::Thing.new(
          thing_template: DataCycleCore::ThingTemplate.new(schema: data_definition),
          convert_storage_location[storage_location] => { 'existing_property' => property_value }
        )
      end

      it 'provides names of plain properties' do
        assert(subject.plain_property_names, ['property', 'existing_property'])
      end

      it 'provides existing data' do
        assert(subject.existing_property, property_value)
      end
    end
  end

  def self.for_properties_with_no_content_yet(storage_location)
    describe "for properties with storage location '#{storage_location}' and no data yet" do
      data_definition = {
        properties: {
          property: {
            label: 'property',
            type: 'string',
            storage_location: storage_location
          }
        }
      }

      subject do
        DataCycleCore::Thing.new(thing_template: DataCycleCore::ThingTemplate.new(schema: data_definition))
      end

      it 'provides names of plain properties' do
        assert(subject.plain_property_names, ['property'])
      end
    end
  end
end

describe DataCycleCore::Content do
  include DataCycleCore::MinitestSpecHelper

  SharedExamplesForContent.for_properties('value') { SecureRandom.hex }

  SharedExamplesForContent.for_properties_with_no_content_yet('translated_value')
  SharedExamplesForContent.for_properties('translated_value') { SecureRandom.hex }

  describe 'with translatable and untranslatable properties' do
    subject do
      DataCycleCore::Thing.new(
        thing_template: DataCycleCore::ThingTemplate.new(schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            name: {
              label: 'name',
              type: 'string',
              storage_location: 'translated_value'
            },
            '1' => {
              label: '1',
              type: 'string',
              storage_location: 'value'
            },
            '2' => {
              label: '2',
              type: 'string',
              storage_location: 'value'
            },
            '3' => {
              label: '3',
              type: 'string',
              storage_location: 'translated_value'
            }
          }
        })
      )
    end

    it 'provides names of plain properties' do
      assert(subject.plain_property_names, ['id', 'name', '1', '2', '3'])
    end

    it 'provides methods for all property names as string' do
      ['id', 'name', '1', '2', '3'].each do |item|
        assert(subject.respond_to?(item))
        assert(subject.respond_to?("#{item}="))
      end
    end

    it 'provides methods for all property names as symbol' do
      ['id', 'name', '1', '2', '3'].each do |item|
        assert(subject.respond_to?(item.to_sym))
        assert(subject.respond_to?("#{item}=".to_sym))
      end
    end

    it 'fails to provide methods for properties that are not specified in the subject' do
      ['abcd', 'jklm'].each do |item|
        assert_equal(subject.respond_to?(item), false)
        assert_equal(subject.respond_to?(item.to_sym), false)
        assert_equal(subject.respond_to?("#{item}="), false)
        assert_equal(subject.respond_to?("#{item}=".to_sym), false)
      end
    end

    it 'raises NameError when not specified methods are called' do
      ['abcd', 'jklm'].each do |item|
        assert_raises NameError do
          subject.method(item).call
        end
        assert_raises NameError do
          subject.method("#{item}=").call('test')
        end
      end
    end

    it 'provides list of untranslatable properties' do
      assert(subject.untranslatable_property_names, ['id', '1', '2'])
    end

    it 'provides list of translatable properties' do
      assert(subject.translatable_property_names, ['name', '3'])
    end
  end

  describe 'with linked properties' do
    subject do
      DataCycleCore::Thing.new(
        thing_template: DataCycleCore::ThingTemplate.new(schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            existing_locations: {
              label: 'Location',
              type: 'linked'
            },
            existing_main_location: {
              label: 'Main Location',
              type: 'linked'
            }
          },
          metadata: {
            existing_locations: [1, 2, 3],
            existing_main_location: 1
          }
        })
      )
    end

    it 'provides names of linked properties' do
      assert(subject.linked_property_names, ['existing_locations', 'existing_main_location'])
    end

    # Test does not work with Time.zone.now
    # it "provides existing data for linked array" do
    #   subject.(:load_linked_data)
    #     .with("places", [1, 2, 3], Time.zone.now, true)
    #     .and_return([double('DataCycleCore::Place'), double('DataCycleCore::Place'), double('DataCycleCore::Place')])
    #
    #   assert(subject.existing_locations.size, 3)
    # end
    #
    # it "provides existing data for single linked object" do
    #   subject.must_receive(:load_linked_data)
    #     .with("places", 1, Time.zone.now , true)
    #     .and_return(double('DataCycleCore::Place'))
    #
    #   expect(subject.existing_main_location).not_to be_nil
    # end
  end

  describe 'with embedded properties' do
    subject do
      DataCycleCore::Thing.new(
        thing_template: DataCycleCore::ThingTemplate.new(schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            existing_locations: {
              label: 'Location',
              type: 'embedded'
            },
            nested_creative_works: {
              label: 'Nested Data',
              type: 'embedded'
            }
          }
        })
      )
    end

    it 'provides names of embedded properties' do
      assert(subject.embedded_property_names, ['existing_locations', 'nested_creative_works'])
    end
  end

  describe 'with included properties' do
    subject do
      DataCycleCore::Thing.new(
        thing_template: DataCycleCore::ThingTemplate.new(schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            description: {
              label: 'description',
              type: 'string',
              storage_location: 'translated_value'
            },
            included_object: {
              label: 'Nested Data',
              type: 'object',
              storage_location: 'value',
              properties: {
                property1: {
                  label: 'property_name a',
                  type: 'string',
                  storage_location: 'value'
                },
                property2: {
                  label: 'property_name b',
                  type: 'string',
                  storage_location: 'value'
                }
              }
            }
          }
        }),
        metadata: {
          'included_object' => {
            'property1' => 'data property1',
            'property2' => 'data property2'
          }
        },
        description: 'dies ist ein Test'
      )
    end

    it 'provides names of included property' do
      assert(subject.included_property_names, ['included_object'])
    end

    it 'provides plain_property_names' do
      assert(subject.plain_property_names, ['id', 'description'])
    end

    it 'provides translatable_property_names' do
      assert(subject.translatable_property_names, ['description'])
    end

    it 'returns value for translatable_property' do
      assert(subject.description, 'dies ist ein Test')
    end

    it 'returns an hash for included property' do
      assert(subject.included_object.to_h.deep_stringify_keys, { 'property1' => 'data property1', 'property2' => 'data property2' })
    end

    it 'returns values for included sub_properties' do
      assert(subject.included_object.property1, 'data property1')
      assert(subject.included_object.property2, 'data property2')
    end

    it 'return a proper hash with :to_h' do
      assert(
        subject.to_h,
        {
          'id' => nil,
          'description' => 'dies ist ein Test',
          'included_object' => {
            'property1' => 'data property1',
            'property2' => 'data property2'
          }
        }
      )
    end
  end

  describe 'with included properties, two ranks deep' do
    subject do
      DataCycleCore::Thing.new(
        thing_template: DataCycleCore::ThingTemplate.new(schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            description: {
              label: 'description',
              type: 'string',
              storage_location: 'translated_value'
            },
            included_object: {
              label: 'Nested Data',
              type: 'object',
              storage_location: 'value',
              properties: {
                property1: {
                  label: 'property_name a',
                  type: 'string',
                  storage_location: 'value'
                },
                property2: {
                  label: 'property_name b',
                  type: 'string',
                  storage_location: 'value'
                },
                deep_included_object: {
                  label: 'Nested Data',
                  type: 'object',
                  storage_location: 'value',
                  properties: {
                    property_deep1: {
                      label: 'deep_property_name a',
                      type: 'string',
                      storage_location: 'value'
                    },
                    property_deep2: {
                      label: 'deep_property_name b',
                      type: 'string',
                      storage_location: 'value'
                    },
                    deeper_object: {
                      label: 'deeper Data',
                      type: 'object',
                      storage_location: 'value',
                      properties: {
                        property_deeper: {
                          label: 'deeper_property_name ',
                          type: 'string',
                          storage_location: 'value'
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }),
        metadata: {
          'included_object' => {
            'property1' => 'data property1',
            'property2' => 'data property2',
            'deep_included_object' => {
              'property_deep1' => 'data property_deep1',
              'property_deep2' => 'data property_deep2',
              'deeper_object' => {
                'property_deeper' => 'deeper_property_name'
              }
            }
          }
        },
        description: 'dies ist ein Test'
      )
    end

    it 'returns an hash for included property' do
      assert(
        subject.included_object.to_h,
        {
          'property1' => 'data property1',
          'property2' => 'data property2',
          'deep_included_object' => {
            'property_deep1' => 'data property_deep1',
            'property_deep2' => 'data property_deep2',
            'deeper_object' => { 'property_deeper' => 'deeper_property_name' }
          }
        }
      )
    end

    it 'returns values for included sub_properties' do
      assert(subject.included_object.property1, 'data property1')
      assert(subject.included_object.property2, 'data property2')
    end

    it 'returns deep_included_object' do
      assert(
        subject.included_object.deep_included_object.to_h,
        {
          'property_deep1' => 'data property_deep1',
          'property_deep2' => 'data property_deep2',
          'deeper_object' => { 'property_deeper' => 'deeper_property_name' }
        }
      )
    end

    it 'returns attributes for deep_included_object' do
      assert(subject.included_object.deep_included_object.property_deep1, 'data property_deep1')
      assert(subject.included_object.deep_included_object.property_deep2, 'data property_deep2')
    end

    it 'returns attribues for deeper_object' do
      assert(subject.included_object.deep_included_object.deeper_object.to_h, { 'property_deeper' => 'deeper_property_name' })
    end

    it 'returns values for deepest level' do
      assert(subject.included_object.deep_included_object.deeper_object.property_deeper, 'deeper_property_name')
    end

    it 'returns all data :to_h ' do
      assert(
        subject.to_h,
        {
          'id' => nil,
          'description' => 'dies ist ein Test',
          'included_object' => {
            'property1' => 'data property1',
            'property2' => 'data property2',
            'deep_included_object' => {
              'property_deep1' => 'data property_deep1',
              'property_deep2' => 'data property_deep2',
              'deeper_object' => { 'property_deeper' => 'deeper_property_name' }
            }
          }
        }
      )
    end
  end

  describe 'with included properties, different types' do
    subject do
      DataCycleCore::Thing.new(
        thing_template: DataCycleCore::ThingTemplate.new(schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            description: {
              label: 'description',
              type: 'string',
              storage_location: 'translated_value'
            },
            included_object: {
              label: 'Nested Data',
              type: 'object',
              storage_location: 'value',
              properties: {
                property1: {
                  label: 'property_name a',
                  type: 'string',
                  storage_location: 'value'
                },
                property2: {
                  label: 'property_name b',
                  type: 'string',
                  storage_location: 'value'
                }
              }
            }
          }
        }),
        metadata: {
          'included_object' => {
            'property1' => 'data property1',
            'property2' => 'data property2'
          }
        },
        description: 'dies ist ein Test'
      )
    end

    it 'returns an hash for included property' do
      assert(
        subject.included_object.to_h,
        {
          'property1' => 'data property1',
          'property2' => 'data property2'
        }
      )
    end

    it 'throws an exception of wrong data_definition are given ' do
      subject.schema['properties']['included_object']['properties']['property1']['storage_location'] = 'Tschibuti'
      assert_raises StandardError do
        subject.included_object
      end
    end

    it 'returns values for included sub_properties' do
      assert(subject.included_object.property1, 'data property1')
      assert(subject.included_object.property2, 'data property2')
    end

    it 'returns all data :to_h ' do
      assert(
        subject.to_h,
        {
          'id' => nil,
          'description' => 'dies ist ein Test',
          'included_object' => {
            'property1' => 'data property1',
            'property2' => 'data property2'
          }
        }
      )
    end
  end
end
