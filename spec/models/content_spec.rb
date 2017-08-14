require 'rails_helper'

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

    it "provides list of untranslatable properties" do
      expect(subject.untranslatable_property_names).to eq(['id', '1', '2'])
    end

    it "provides list of translatable properties" do
      expect(subject.translatable_property_names).to eq(['headline', '3', '4'])

      byebug
    end
  end
end
