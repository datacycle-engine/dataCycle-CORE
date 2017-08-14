require 'rails_helper'

validation = {
  name: 'Bild',
  description: 'ImageObject',
  type: 'object',
  properties: {
    metadata_property: {
      label: 'metadata property',
      type: 'string',
      storage_type: 'string',
      storage_location: 'metadata'
    },
    existing_metadata_property: {
      label: 'metadata property',
      type: 'string',
      storage_type: 'string',
      storage_location: 'metadata'
    },
    content_property: {
      label: 'content property',
      type: 'string',
      storage_type: 'string',
      storage_location: 'content'
    },
    existing_content_property: {
      label: 'existing content property',
      type: 'string',
      storage_type: 'string',
      storage_location: 'content'
    },
    properties_property: {
      label: 'properties property',
      type: 'string',
      storage_type: 'string',
      storage_location: 'properties'
    },
    existing_properties_property: {
      label: 'existing properties property',
      type: 'string',
      storage_type: 'string',
      storage_location: 'properties'
    }
  }
}

RSpec.describe DataCycleCore::Content, type: :model do
  subject {
    DataCycleCore::CreativeWork.new(metadata: {validation: validation, 'existing_metadata_property' => 'some existing metadata'})
  }

  it "provides existing data of property with storage location 'metadata'" do
    expect(subject.existing_metadata_property).to eq('some existing metadata')
    expect(subject.metadata['existing_metadata_property']).to eq('some existing metadata')
  end

  it "sets a property with 'metadata' as storage location" do
    subject.metadata_property = 'some data'

    expect(subject.metadata_property).to eq('some data')
    expect(subject.metadata['metadata_property']).to eq('some data')
  end

  describe "with no content yet" do
    it "sets a property with 'content' as storage location" do
      subject.content_property = 'some data'

      expect(subject.content_property).to eq('some data')
      expect(subject.content['content_property']).to eq('some data')
    end

    it "sets a property with 'properties' as storage location" do
      subject.properties_property = 'some data'

      expect(subject.properties_property).to eq('some data')
      expect(subject.properties['properties_property']).to eq('some data')
    end
  end

  describe "with content" do
    before(:each) { subject.content = {'existing_content_property' => 'this is some content'} }

    it "provides existing data of property with storage location 'content'" do
      expect(subject.existing_content_property).to eq('this is some content')
    end

    it "sets a property with 'content' as storage location" do
      subject.content_property = 'some data'

      expect(subject.content_property).to eq('some data')
      expect(subject.content['content_property']).to eq('some data')
    end

    it "does not override existing data" do
      subject.content_property = 'some data'

      expect(subject.existing_content_property).to eq('this is some content')
      expect(subject.content['existing_content_property']).to eq('this is some content')
    end
  end

  describe "with properties" do
    before(:each) { subject.properties = {'existing_properties_property' => 'this is existing property data'} }

    it "provides existing data of property with storage location 'properties'" do
      expect(subject.existing_properties_property).to eq('this is existing property data')
    end

    it "sets a property with 'properties' as storage location" do
      subject.properties_property = 'some data'

      expect(subject.properties_property).to eq('some data')
      expect(subject.properties['properties_property']).to eq('some data')
    end 

    it "does not override existing data" do
      subject.properties_property = 'some data'

      expect(subject.existing_properties_property).to eq('this is existing property data')
      expect(subject.properties['existing_properties_property']).to eq('this is existing property data')
    end       
  end
end
