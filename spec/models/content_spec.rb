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
end
