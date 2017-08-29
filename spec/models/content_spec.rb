require 'rails_helper'


hashify = lambda do |struct|
  as_hash = struct.to_h
  struct_keys = as_hash.select { |_, v| v.is_a? OpenStruct }.map(&:first)
  struct_keys.each { |key| as_hash[key] = hashify.(as_hash[key]) }
  as_hash
end


RSpec.shared_examples "for properties" do |storage_location, data_provider|
  describe "for properties with storage location '#{storage_location}'" do
    data_definition = {
        validation: {
          properties: {
            property: {
              label: 'property',
              type: 'string',
              storage_type: 'string',
              storage_location: storage_location
            },
            existing_property: {
              label: 'existing property',
              type: 'string',
              storage_type: 'string',
              storage_location: storage_location
            }
          }
        }
      }

    property_value = data_provider.call

    subject {
      if storage_location == 'metadata'
        DataCycleCore::CreativeWork.new(metadata: data_definition.merge({'existing_property' => property_value}))
      else
        DataCycleCore::CreativeWork.new(metadata: data_definition, storage_location => {'existing_property' => property_value})
      end
    }

    it "provides names of plain properties" do
      expect(subject.plain_property_names).to eq(['property', 'existing_property'])
    end

    it "provides existing data" do
      expect(subject.existing_property).to eq(property_value)
    end

    it "updates existing data" do
      different_property_value = data_provider.call
      subject.existing_property = different_property_value

      expect(subject.existing_property).to eq(different_property_value)
    end

    it "creates data for new property" do
      subject.property = "some data"

      expect(subject.property).to eq('some data')
    end
  end
end

RSpec.shared_examples "for properties with no content yet" do |storage_location|
  describe "for properties with storage location '#{storage_location}' and no data yet" do
    data_definition = {
        validation: {
          properties: {
            property: {
              label: 'property',
              type: 'string',
              storage_type: 'string',
              storage_location: storage_location
            }
          }
        }
      }

    subject {
      DataCycleCore::CreativeWork.new(metadata: data_definition)
    }

    it "provides names of plain properties" do
      expect(subject.plain_property_names).to eq(['property'])
    end

    it "creates data for new property" do
      subject.property = "some data"

      expect(subject.property).to eq('some data')
    end
  end
end

RSpec.describe DataCycleCore::Content, type: :model do
  include_context "for properties", "metadata",  ->() { SecureRandom.hex }

  include_context "for properties with no content yet", "content",  ->() { SecureRandom.hex }
  include_context "for properties", "content",  ->() { SecureRandom.hex }

  include_context "for properties with no content yet", "properties",  ->() { SecureRandom.hex }
  include_context "for properties", "properties",  ->() { SecureRandom.hex }

  describe "with translatable and untranslatable properties" do
    subject {
      DataCycleCore::CreativeWork.new(metadata: {
          validation: {
            properties: {
              id: {
                label: 'id',
                type: 'string',
                storage_type: 'string',
                storage_location: 'key'
              },
              headline: {
                label: 'headline',
                type: 'string',
                storage_type: 'string',
                storage_location: 'column'
              },
              '1' => {
                label: '1',
                type: 'string',
                storage_type: 'string',
                storage_location: 'metadata'
              },
              '2' => {
                label: '2',
                type: 'string',
                storage_type: 'string',
                storage_location: 'metadata'
              },
              '3' => {
                label: '3',
                type: 'string',
                storage_type: 'string',
                storage_location: 'content'
              },
              '4' => {
                label: '4',
                type: 'string',
                storage_type: 'string',
                storage_location: 'properties'
              }
            }
          }
        })
    }

    it "provides names of plain properties" do
      expect(subject.plain_property_names).to eq(['id', 'headline', '1', '2', '3', '4'])
    end

    it "provides methods for all property names as string" do
      ['id', 'headline', '1', '2', '3', '4'].each do |item|
        expect(subject).to respond_to item
        expect(subject).to respond_to "#{item}="
      end
    end

    it "provides methods for all property names as symbol" do
      ['id', 'headline', '1', '2', '3', '4'].each do |item|
        expect(subject).to respond_to item.to_sym
        expect(subject).to respond_to "#{item}=".to_sym
      end
    end

    it "fails to provide methods for properties that are not specified in the subject" do
      ['abcd', 'jklm'].each do |item|
        expect(subject.respond_to? item).to be false
        expect(subject.respond_to? item.to_sym).to be false
        expect(subject.respond_to? "#{item}=").to be false
        expect(subject.respond_to? "#{item}=".to_sym).to be false
      end
    end

    it "raises NameError when not specified methods are called" do
      ['abcd', 'jklm'].each do |item|
        expect{ subject.method(item).call() }.to raise_error(NameError)
        expect{ subject.method("#{item}=").call("test") }.to raise_error(NameError)
      end
    end

    it "provides list of untranslatable properties" do
      expect(subject.untranslatable_property_names).to eq(['id', '1', '2'])
    end

    it "provides list of translatable properties" do
      expect(subject.translatable_property_names).to eq(['headline', '3', '4'])
    end
  end

  describe "with linked properties" do
    subject {
      DataCycleCore::CreativeWork.new(metadata: {
          validation: {
            properties: {
              id: {
                label: 'id',
                type: 'string',
                storage_type: 'string',
                storage_location: 'key'
              },
              existing_locations: {
                label: 'Location',
                type: 'embeddedLinkArray',
                type_name: 'places',
                storage_type: 'array',
                storage_location: 'metadata',
              },
              existing_main_location: {
                label: 'Main Location',
                type: 'embeddedLink',
                type_name: 'places',
                storage_type: 'number',
                storage_location: 'metadata',
              }
            }
          },
          existing_locations: [1, 2, 3],
          existing_main_location: 1
        })
    }

    it "provides names of linked properties" do
      expect(subject.linked_property_names).to eq(['existing_locations', 'existing_main_location'])
    end

    it "provides existing data for linked array" do
      expect(subject).to receive(:load_linked_data)
        .with('DataCycleCore::Place', [1, 2, 3])
        .and_return([double('DataCycleCore::Place'), double('DataCycleCore::Place'), double('DataCycleCore::Place')])

      expect(subject.existing_locations.size).to eq(3)
    end

    it "provides existing data for single linked object" do
      expect(subject).to receive(:load_linked_data)
        .with('DataCycleCore::Place', 1)
        .and_return(double('DataCycleCore::Place'))

      expect(subject.existing_main_location).not_to be_nil
    end
  end

  describe "with embedded properties" do
    subject {
      DataCycleCore::CreativeWork.new(metadata: {
          validation: {
            properties: {
              id: {
                label: 'id',
                type: 'string',
                storage_type: 'string',
                storage_location: 'key'
              },
              existing_locations: {
                label: 'Location',
                type: 'object',
                storage_location: 'places'
              },
              nested_creative_works: {
                label: 'Nested Data',
                type: 'object',
                storage_location: 'creative_works'
              }
            }
          },
          nested_creative_works_hasPart: [3, 6, 9]
        })
    }

    it "provides names of embedded properties" do
      expect(subject.embedded_property_names).to eq(['existing_locations', 'nested_creative_works'])
    end

    it "provides existing data from different table" do
      expect(subject).to receive(:places)
        .and_return([double('DataCycleCore::Place'), double('DataCycleCore::Place'), double('DataCycleCore::Place')])

      expect(subject.existing_locations.size).to eq(3)
    end

    it "provides existing data from same table" do
      expect(subject).to receive(:load_linked_data)
        .with('DataCycleCore::CreativeWork', [3, 6, 9])
        .and_return([double('DataCycleCore::CreativeWork'), double('DataCycleCore::CreativeWork'), double('DataCycleCore::CreativeWork')])

      expect(subject.nested_creative_works.size).to eq(3)
    end
  end

  describe "with included properties" do
    subject {
      DataCycleCore::CreativeWork.new(metadata: {
          validation: {
            properties: {
              id: {
                label: 'id',
                type: 'string',
                storage_type: 'string',
                storage_location: 'key'
              },
              description: {
                label: 'description',
                type: 'string',
                storage_type: 'string',
                storage_location: 'column'
              },
              included_object: {
                label: 'Nested Data',
                type: 'object',
                storage_location: 'metadata',
                properties: {
                  property1: {
                    label: 'property_name a',
                    type: 'string',
                    storage_type: 'string',
                    storage_location: 'metadata'
                  },
                  property2: {
                    label: 'property_name b',
                    type: 'string',
                    storage_type: 'string',
                    storage_location: 'metadata'
                  }
                }
              }
            }
          },
          "included_object" => {
            "property1" => "data property1",
            "property2" => "data property2"
          }
        },
        description: "dies ist ein Test"
      )
    }

    it "provides names of included property" do
      expect(subject.embedded_property_names).to eq(['included_object'])
    end

    it "provides plain_property_names" do
      expect(subject.plain_property_names).to eq(['id', 'description'])
    end

    it "provides translatable_property_names" do
      expect(subject.translatable_property_names).to eq(['description'])
    end

    it "returns value for translatable_property" do
      expect(subject.description).to eq("dies ist ein Test")
    end

    it "returns an hash for included property" do
      expect(subject.included_object.to_h.deep_stringify_keys).to eq({"property1" => "data property1", "property2" => "data property2"})
    end

    it "returns values for included sub_properties" do
      expect(subject.included_object.property1).to eq("data property1")
      expect(subject.included_object.property2).to eq("data property2")
    end

  end

  describe "with included properties, two ranks deep" do

    subject {
      DataCycleCore::CreativeWork.new(metadata: {
          validation: {
            properties: {
              id: {
                label: 'id',
                type: 'string',
                storage_type: 'string',
                storage_location: 'key'
              },
              description: {
                label: 'description',
                type: 'string',
                storage_type: 'string',
                storage_location: 'column'
              },
              included_object: {
                label: 'Nested Data',
                type: 'object',
                storage_location: 'metadata',
                properties: {
                  property1: {
                    label: 'property_name a',
                    type: 'string',
                    storage_type: 'string',
                    storage_location: 'metadata'
                  },
                  property2: {
                    label: 'property_name b',
                    type: 'string',
                    storage_type: 'string',
                    storage_location: 'metadata'
                  },
                  deep_included_object: {
                    label: 'Nested Data',
                    type: 'object',
                    storage_location: 'metadata',
                    properties: {
                      property_deep1: {
                        label: 'deep_property_name a',
                        type: 'string',
                        storage_type: 'string',
                        storage_location: 'metadata'
                      },
                      property_deep2: {
                        label: 'deep_property_name b',
                        type: 'string',
                        storage_type: 'string',
                        storage_location: 'metadata'
                      },
                      deeper_object: {
                        label: 'deeper Data',
                        type: 'object',
                        storage_location: 'metadata',
                        properties: {
                          property_deeper: {
                            label: 'deeper_property_name ',
                            type: 'string',
                            storage_type: 'string',
                            storage_location: 'metadata'
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          },
          "included_object" => {
            "property1" => "data property1",
            "property2" => "data property2",
            "deep_included_object" => {
              "property_deep1" => "data property_deep1",
              "property_deep2" => "data property_deep2",
              "deeper_object" => {
                "property_deeper" => "deeper_property_name"
              }
            }
          }
        },
        description: "dies ist ein Test"
      )
    }

    it "returns an hash for included property" do
      expect(hashify.(subject.included_object).deep_stringify_keys).to eq({
        "property1" => "data property1",
        "property2" => "data property2",
        "deep_included_object" => {
          "property_deep1" => "data property_deep1",
          "property_deep2" => "data property_deep2",
          "deeper_object" => {"property_deeper" => "deeper_property_name"}
        }
      })
    end

    it "returns values for included sub_properties" do
      expect(subject.included_object.property1).to eq("data property1")
      expect(subject.included_object.property2).to eq("data property2")
    end

    it "returns deep_included_object" do
      expect(hashify.(subject.included_object.deep_included_object).deep_stringify_keys).to eq({
        "property_deep1" => "data property_deep1",
        "property_deep2" => "data property_deep2",
        "deeper_object" => {"property_deeper" => "deeper_property_name"}
      })
    end

    it "returns attributes for deep_included_object" do
      expect(subject.included_object.deep_included_object.property_deep1).to eq("data property_deep1")
      expect(subject.included_object.deep_included_object.property_deep2).to eq("data property_deep2")
    end

    it "returns attribues for deeper_objext" do
      expect(subject.included_object.deep_included_object.deeper_object.to_h.stringify_keys).to eq({"property_deeper" => "deeper_property_name"})
    end

    it "returns values for deepest level" do
      expect(subject.included_object.deep_included_object.deeper_object.property_deeper).to eq("deeper_property_name")
    end

  end



end
