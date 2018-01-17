require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::ImportTemplates do
  subject do
    DataCycleCore::MasterData::ImportTemplates.new
  end

  describe 'loaded template_data' do
    let(:data_template) do
      {
        :data => {
          :name => "App",
          :description => "CreativeWork",
          :type => "object",
          :content_type => "variant",
          :releasable => true,
          :permissions => { :read_write => true },
          :boost => 100.0,
          :properties => {
            :id => {
              :label => "id",
              :type => "string",
              :storage_type => "string",
              :storage_location => "key",
              :validations => { :format => "uuid" }
            },
            :headline => {
              :label => "Arbeitstitel",
              :type => "string",
              :storage_type => "string",
              :storage_location => "column",
              :search => true,
              :validations => {
                :minLength => 1
              },
              :editor => {
                :type => "input",
                :sorting => 1,
                :options => { :"data-validate" => "text" }
              }
            },
            :headline_external => {
              :label => "Titel",
              :type => "string",
              :storage_type => "string",
              :storage_location => "content",
              :search => true,
              :validations => { :minLength => 1 },
              :editor => {
                :type => "input",
                :sorting => 2,
                :options => { :"data-validate" => "text" }
              }
            },
            :validity_period => {
              :label => "Gültigkeitszeitraum",
              :type => "object",
              :storage_location => "metadata",
              :validations => {
                :daterange => {
                  :from => "valid_from",
                  :to => "valid_until"
                }
              },
              :editor => {
                :sorting => 3,
                :options => {
                  :class => "daterange",
                  :tabindex => -1
                }
              },
              :properties => {
                :valid_from => {
                  :label => "Gültigkeit",
                  :type => "string",
                  :storage_type => "string",
                  :storage_location => "metadata",
                  :validations => { :format => "date_time" },
                  :editor => {
                    :type => "date",
                    :options => {
                      :"data-type" => "datepicker",
                      :"data-validate" => "daterange",
                      :placeholder => "tt.mm.jjjj"
                    }
                  }
                },
                :valid_until => {
                  :label => "bis",
                  :type => "string",
                  :storage_type => "string",
                  :storage_location => "metadata",
                  :validations => { :format => "date_time" },
                  :editor => {
                    :type => "date",
                    :options => {
                      :"data-type" => "datepicker",
                      :"data-validate" => "daterange",
                      :placeholder => "tt.mm.jjjj"
                    }
                  }
                }
              }
            },
            :alternative_headline => {
              :label => "Subüberschrift",
              :type => "string",
              :storage_type => "string",
              :storage_location => "content",
              :search => true,
              :editor => {
                :type => "input",
                :sorting => 4
              }
            },
            :description => {
              :label => "Teasertext",
              :type => "string",
              :storage_type => "text",
              :storage_location => "column",
              :search => true,
              :editor => {
                :type => "quillEditor",
                :sorting => 5,
                :options => {
                  :"data-size" => "basic",
                  :tabindex => -1
                }
              }
            },
            :image => {
              :label => "Bild",
              :type => "embeddedLinkArray",
              :type_name => "creative_works",
              :storage_type => "array",
              :storage_location => "metadata",
              :validations => { :max => 1 },
              :editor => {
                :sorting => 10,
                :type => "objectBrowser",
                :options => {
                  :"data-validate" => "media",
                  :"data-type" => "image"
                }
              }
            },
            :video => {
              :label => "Video",
              :type => "embeddedLinkArray",
              :type_name => "creative_works",
              :storage_type => "array",
              :storage_location => "metadata",
              :validations => { :max => 1 },
              :editor => {
                :sorting => 11,
                :type => "objectBrowser",
                :options => {
                  :"data-validate" => "media",
                  :"data-type" => "video"
                }
              }
            },
            :mobile_application => {
              :label => "Link",
              :type => "object",
              :storage_location => "creative_works",
              :delete => true,
              :name => "MobileApplication",
              :description => "CreativeWork",
              :editor => {
                :type => "embeddedObject",
                :sorting => 12
              }
            },
            :topics => {
              :label => "Themenbereiche",
              :type => "classificationTreeLabel",
              :type_name => "Themenbereiche",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 20,
                :options => { :tabindex => -1 }
              }
            },
            :markets => {
              :label => "Zielmarkt",
              :type => "classificationTreeLabel",
              :type_name => "Märkte",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 21,
                :options => { :tabindex => -1 }
              }
            },
            :kind => {
              :label => "Inhaltsart",
              :type => "classificationTreeLabel",
              :type_name => "Inhaltsarten",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 22,
                :options => { :tabindex => -1 }
              }
            },
            :season => {
              :label => "Jahreszeit",
              :type => "classificationTreeLabel",
              :type_name => "Jahreszeiten",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 23,
                :options => { :tabindex => -1 }
              }
            },
            :state => {
              :label => "Bundesland",
              :type => "classificationTreeLabel",
              :type_name => "Bundesländer",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 24,
                :options => {
                  :"data-validate" => "classification",
                  :tabindex => -1
                }
              }
            },
            :tags => {
              :label => "Tags",
              :type => "classificationTreeLabel",
              :type_name => "Tags",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 25,
                :options => { :tabindex => -1 }
              }
            },
            :output_channels => {
              :label => "Ausgabekanäle",
              :type => "classificationTreeLabel",
              :type_name => "Ausgabekanäle",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 26,
                :options => { :tabindex => -1 }
              }
            },
            :permitted_creator => {
              :label => "Ersteller",
              :type => "classificationTreeLabel",
              :type_name => "Ersteller",
              :storage_location => "classification_relation",
              :editor => {
                :type => "classificationSelector",
                :sorting => 27,
                :options => { :tabindex => -1 }
              }
            },
            :data_pool => {
              :label => "Inhaltspool",
              :type => "classificationTreeLabel",
              :type_name => "Inhaltspools",
              :storage_location => "classification_relation",
              :default_value => "Aktuelle Inhalte"
            },
            :data_type => {
              :label => "Inhaltstype",
              :type => "classificationTreeLabel",
              :type_name => "Inhaltstypen",
              :storage_location => "classification_relation",
              :default_value => "App"
            },
            :creator => {
              :label => "Ersteller",
              :type => "embeddedLink",
              :type_name => "users",
              :storage_type => "string",
              :storage_location => "metadata"
            },
            :date_created => {
              :label => "Erstellungsdatum",
              :type => "string",
              :storage_type => "string",
              :storage_location => "metadata",
              :validations => { :format => "date_time" }
            },
            :date_modified => {
              :label => "Änderungsdatum",
              :type => "string",
              :storage_type => "string",
              :storage_location => "metadata",
              :validations => { :format => "date_time" }
            }
          }
        }
      }
    end

    let(:header_hash) do
      {
        data: {
          name: 'whatever',
          description: 'CreativeWork',
          type: 'object'
        }
      }
    end

    let(:simple_property_hash) do
      {
        label: 'whatever',
        type: 'string',
        storage_type: 'string',
        storage_location: 'column'
      }
    end

    let(:classification_relation_hash) do
      {
        label: 'whatever',
        type: 'classificationTreeLabel',
        type_name: 'Inhaltspools',
        storage_location: 'classification_relation',
        default_value: 'Aktuelle Inhalte'
      }
    end

    let(:embedded_object_hash) do
      {
        label: 'whatever',
        type: 'object',
        storage_location: 'creative_works',
        name: 'MobileApplication',
        description: 'CreativeWork'
      }
    end

    let(:included_object_hash) do
      {
        label: 'whatever',
        type: 'object',
        storage_location: 'metadata',
        properties: {
          propertyA: {
            label: 'label Property A',
            type: 'string',
            storage_type: 'string',
            storage_location: 'metadata'
          },
          propertyB: {
            label: 'label Property B',
            type: 'string',
            storage_type: 'string',
            storage_location: 'metadata'
          }
        }
      }
    end

    it 'check a complex data_template' do
      errors = subject.validate(data_template)
      assert errors == {}
    end

    it 'checks for valid value of name attribute in header' do
      test_hash = header_hash
      test_hash[:data][:name] = nil
      assert !subject.validate_header.(test_hash).success?
    end

    it 'checks for presence of name attribute in header' do
      test_hash = {}
      test_hash[:data] = header_hash[:data].except(:name)
      assert !subject.validate_header.(test_hash).success?
    end

    it 'checks for valid value of description in header' do
      test_hash = header_hash
      test_hash[:data][:description] = nil
      assert !subject.validate_header.(test_hash).success?
    end

    it 'checks for presence of description attribute in header' do
      test_hash = {}
      test_hash[:data] = header_hash[:data].except(:description)
      assert !subject.validate_header.(test_hash).success?
    end

    it 'checks for valid value of description in header' do
      test_hash = header_hash
      test_hash[:data][:type] = nil
      assert !subject.validate_header.(test_hash).success?
    end

    it 'checks for wrong string value of description in header' do
      test_hash = header_hash
      test_hash[:data][:type] = 'string'
      assert !subject.validate_header.(test_hash).success?
    end

    it 'checks for presence of description attribute in header' do
      test_hash = {}
      test_hash[:data] = header_hash[:data].except(:type)
      assert !subject.validate_header.(test_hash).success?
    end

    it 'checks properties for presence of label' do
      test_hash = simple_property_hash.except(:label)
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for label is a string' do
      test_hash = simple_property_hash
      test_hash[:label] = nil
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for presence of type' do
      test_hash = simple_property_hash.except(:type)
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for type is a string' do
      test_hash = simple_property_hash
      test_hash[:type] = nil
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for type is a wrong string' do
      test_hash = simple_property_hash
      test_hash[:type] = 'long'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for valid types' do
      test_hash = simple_property_hash
      available_types = ['string', 'text', 'number', 'geographic']
      available_types.each do |type_name|
        test_hash[:type] = type_name
        assert subject.validate_property.(test_hash).success?
      end
    end

    it 'checks properties for storage_type is a string' do
      test_hash = simple_property_hash
      test_hash[:storage_type] = nil
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for storage_type is a wrong string' do
      test_hash = simple_property_hash
      test_hash[:storage_type] = 'long'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for valid storage_types' do
      test_hash = simple_property_hash
      available_storage_types = ['string', 'text', 'number', 'geographic', 'array']
      available_storage_types.each do |storage_type_name|
        test_hash[:storage_type] = storage_type_name
        assert subject.validate_property.(test_hash).success?
      end
    end

    it 'checks properties for storage_location is a string' do
      test_hash = simple_property_hash
      test_hash[:storage_location] = nil
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for storage_location is a wrong string' do
      test_hash = simple_property_hash
      test_hash[:storage_location] = 'long'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks properties for valid storage_location' do
      test_hash = simple_property_hash
      available_storage_locations = ['key', 'column', 'metadata', 'content', 'properties']
      available_storage_locations.each do |storage_location|
        test_hash[:storage_location] = storage_location
        assert subject.validate_property.(test_hash).success?
      end
    end

    it 'checks correct classification_relation' do
      test_hash = classification_relation_hash
      assert subject.validate_property.(test_hash).success?
    end

    it 'checks classification_relation for presence of type_name' do
      test_hash = classification_relation_hash.except(:type_name)
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks classification_relation works without default_value' do
      test_hash = classification_relation_hash.except(:default_value)
      assert subject.validate_property.(test_hash).success?
    end

    it 'checks classification_relation error for wrong default_value' do
      test_hash = classification_relation_hash
      test_hash[:default_value] = 'wrong name'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks correct embedded_object_hash' do
      test_hash = embedded_object_hash
      assert subject.validate_property.(test_hash).success?
    end

    it 'checks embedded_object for wrong type' do
      test_hash = embedded_object_hash
      test_hash[:type] = 'string'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks embedded_object for correct storage_location' do
      test_hash = embedded_object_hash
      test_hash[:storage_location] = 'content'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks embedded_object for correct description' do
      test_hash = embedded_object_hash
      test_hash[:description] = 'creative_works'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks included_object_hash correctly' do
      test_hash = included_object_hash
      assert subject.validate_property.(test_hash).success?
    end

    it 'checks included_object_hash for wrong type' do
      test_hash = included_object_hash
      test_hash[:type] = 'string'
      assert !subject.validate_property.(test_hash).success?
    end

    it 'checks included_object_hash for wrong storage_locations' do
      test_hash = included_object_hash
      (['key', 'column', 'classification_relation'] + DataCycleCore.content_tables).each do |location|
        test_hash[:storage_location] = location
        assert !subject.validate_property.(test_hash).success?
      end
    end
  end
end
