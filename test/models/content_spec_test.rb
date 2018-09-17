# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

module SharedExamplesForContent
  def self.for_properties(storage_location, &data_provider)
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

      property_value = data_provider.call

      subject do
        convert_storage_location = { 'value' => 'metadata', 'translated_value' => 'content' }
        DataCycleCore::CreativeWork.new(
          schema: data_definition,
          convert_storage_location[storage_location] => { 'existing_property' => property_value }
        )
      end

      it 'provides names of plain properties' do
        subject.plain_property_names.must_equal(['property', 'existing_property'])
      end

      it 'provides existing data' do
        subject.existing_property.must_equal(property_value)
      end

      it 'updates existing data' do
        different_property_value = data_provider.call
        subject.existing_property = different_property_value

        subject.existing_property.must_equal(different_property_value)
      end

      it 'creates data for new property' do
        subject.property = 'some data'

        subject.property.must_equal('some data')
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
        DataCycleCore::CreativeWork.new(schema: data_definition)
      end

      it 'provides names of plain properties' do
        subject.plain_property_names.must_equal(['property'])
      end

      it 'creates data for new property' do
        subject.property = 'some data'

        subject.property.must_equal('some data')
      end
    end
  end
end

describe DataCycleCore::Content do
  SharedExamplesForContent.for_properties('value') { SecureRandom.hex }

  SharedExamplesForContent.for_properties_with_no_content_yet('translated_value')
  SharedExamplesForContent.for_properties('translated_value') { SecureRandom.hex }

  describe 'with translatable and untranslatable properties' do
    subject do
      DataCycleCore::CreativeWork.new(
        schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            headline: {
              label: 'headline',
              type: 'string',
              storage_location: 'column'
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
        }
      )
    end

    it 'provides names of plain properties' do
      subject.plain_property_names.must_equal(['id', 'headline', '1', '2', '3'])
    end

    it 'provides methods for all property names as string' do
      ['id', 'headline', '1', '2', '3'].each do |item|
        subject.must_respond_to item
        subject.must_respond_to "#{item}="
      end
    end

    it 'provides methods for all property names as symbol' do
      ['id', 'headline', '1', '2', '3'].each do |item|
        subject.must_respond_to item.to_sym
        subject.must_respond_to "#{item}=".to_sym
      end
    end

    it 'fails to provide methods for properties that are not specified in the subject' do
      ['abcd', 'jklm'].each do |item|
        subject.respond_to?(item).must_equal false
        subject.respond_to?(item.to_sym).must_equal false
        subject.respond_to?("#{item}=").must_equal false
        subject.respond_to?("#{item}=".to_sym).must_equal false
      end
    end

    it 'raises NameError when not specified methods are called' do
      ['abcd', 'jklm'].each do |item|
        proc { subject.method(item).call }.must_raise NameError
        proc { subject.method("#{item}=").call('test') }.must_raise NameError
      end
    end

    it 'provides list of untranslatable properties' do
      subject.untranslatable_property_names.must_equal(['id', '1', '2'])
    end

    it 'provides list of translatable properties' do
      subject.translatable_property_names.must_equal(['headline', '3'])
    end
  end

  describe 'with linked properties' do
    subject do
      DataCycleCore::CreativeWork.new(
        schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            existing_locations: {
              label: 'Location',
              type: 'linked',
              linked_table: 'places'
            },
            existing_main_location: {
              label: 'Main Location',
              type: 'linked',
              linked_table: 'places'
            }
          },
          metadata: {
            existing_locations: [1, 2, 3],
            existing_main_location: 1
          }
        }
      )
    end

    it 'provides names of linked properties' do
      subject.linked_property_names.must_equal(['existing_locations', 'existing_main_location'])
    end

    # Test does not work with Time.zone.now
    # it "provides existing data for linked array" do
    #   subject.(:load_linked_data)
    #     .with("places", [1, 2, 3], Time.zone.now, true)
    #     .and_return([double('DataCycleCore::Place'), double('DataCycleCore::Place'), double('DataCycleCore::Place')])
    #
    #   subject.existing_locations.size.must_equal(3)
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
      DataCycleCore::CreativeWork.new(
        schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            existing_locations: {
              label: 'Location',
              type: 'embedded',
              linked_table: 'places'
            },
            nested_creative_works: {
              label: 'Nested Data',
              type: 'embedded',
              linked_table: 'creative_works'
            }
          }
        }
      )
    end

    it 'provides names of embedded properties' do
      subject.embedded_property_names.must_equal(['existing_locations', 'nested_creative_works'])
    end
  end

  describe 'with included properties' do
    subject do
      DataCycleCore::CreativeWork.new(
        schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            description: {
              label: 'description',
              type: 'string',
              storage_location: 'column'
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
        },
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
      subject.included_property_names.must_equal(['included_object'])
    end

    it 'provides plain_property_names' do
      subject.plain_property_names.must_equal(['id', 'description'])
    end

    it 'provides translatable_property_names' do
      subject.translatable_property_names.must_equal(['description'])
    end

    it 'returns value for translatable_property' do
      subject.description.must_equal('dies ist ein Test')
    end

    it 'returns an hash for included property' do
      subject.included_object.to_h.deep_stringify_keys.must_equal({ 'property1' => 'data property1', 'property2' => 'data property2' })
    end

    it 'returns values for included sub_properties' do
      subject.included_object.property1.must_equal('data property1')
      subject.included_object.property2.must_equal('data property2')
    end

    it 'return a proper hash with :to_h' do
      subject.to_h.must_equal(
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
      DataCycleCore::CreativeWork.new(
        schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            description: {
              label: 'description',
              type: 'string',
              storage_location: 'column'
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
        },
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
      subject.included_object.to_h.must_equal({
        'property1' => 'data property1',
        'property2' => 'data property2',
        'deep_included_object' => {
          'property_deep1' => 'data property_deep1',
          'property_deep2' => 'data property_deep2',
          'deeper_object' => { 'property_deeper' => 'deeper_property_name' }
        }
      })
    end

    it 'returns values for included sub_properties' do
      subject.included_object.property1.must_equal('data property1')
      subject.included_object.property2.must_equal('data property2')
    end

    it 'returns deep_included_object' do
      subject.included_object.deep_included_object.to_h.must_equal({
        'property_deep1' => 'data property_deep1',
        'property_deep2' => 'data property_deep2',
        'deeper_object' => { 'property_deeper' => 'deeper_property_name' }
      })
    end

    it 'returns attributes for deep_included_object' do
      subject.included_object.deep_included_object.property_deep1.must_equal('data property_deep1')
      subject.included_object.deep_included_object.property_deep2.must_equal('data property_deep2')
    end

    it 'returns attribues for deeper_object' do
      subject.included_object.deep_included_object.deeper_object.to_h.must_equal({ 'property_deeper' => 'deeper_property_name' })
    end

    it 'returns values for deepest level' do
      subject.included_object.deep_included_object.deeper_object.property_deeper.must_equal('deeper_property_name')
    end

    it 'returns all data :to_h ' do
      subject.to_h.must_equal({
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
      })
    end
  end

  describe 'with included properties, different types' do
    subject do
      DataCycleCore::CreativeWork.new(
        schema: {
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            description: {
              label: 'description',
              type: 'string',
              storage_location: 'column'
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
        },
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
      subject.included_object.to_h.must_equal(
        {
          'property1' => 'data property1',
          'property2' => 'data property2'
        }
      )
    end

    it 'returns values for included sub_properties' do
      subject.included_object.property1.must_equal('data property1')
      subject.included_object.property2.must_equal('data property2')
    end

    it 'returns all data :to_h ' do
      subject.to_h.must_equal(
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
