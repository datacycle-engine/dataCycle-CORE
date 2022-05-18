# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::ImportTemplates do
  subject do
    DataCycleCore::MasterData::ImportTemplates
  end

  let(:validate_property) do
    subject::TemplatePropertyContract.new
  end

  let(:validate_header) do
    subject::TemplateHeaderContract.new
  end

  describe 'loaded template_data' do
    let(:data_template) do
      {
        data: {
          name: 'App',
          type: 'object',
          content_type: 'entity',
          schema_type: 'CreativeWork',
          boost: 10.0,
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            headline: {
              label: 'Arbeitstitel',
              type: 'string',
              storage_location: 'column',
              search: true,
              validations: { minLength: 1 }
            },
            headline_external: {
              label: 'Titel',
              type: 'string',
              storage_location: 'translated_value',
              search: true,
              validations: { minLength: 1 }
            },
            validity_period: {
              label: 'Gültigkeitszeitraum',
              type: 'object',
              storage_location: 'translated_value',
              validations: {
                daterange: {
                  from: 'valid_from',
                  to: 'valid_until'
                }
              },
              ui: {
                edit: {
                  options: {
                    class: 'daterange'
                  }
                }
              },
              properties: {
                valid_from: {
                  label: 'Gültigkeit',
                  type: 'date',
                  storage_location: 'translated_value',
                  ui: {
                    edit: {
                      options: {
                        'data-validate': 'daterange',
                        placeholder: 'tt.mm.jjjj'
                      }
                    }
                  }
                },
                valid_until: {
                  label: 'bis',
                  type: 'date',
                  storage_location: 'translated_value',
                  ui: {
                    edit: {
                      options: {
                        'data-validate': 'daterange',
                        placeholder: 'tt.mm.jjjj'
                      }
                    }
                  }
                }
              }
            },
            alternative_headline: {
              label: 'Subüberschrift',
              type: 'string',
              storage_location: 'translated_value',
              search: true
            },
            description: {
              label: 'Teasertext',
              type: 'string',
              storage_location: 'column',
              search: true
            },
            image: {
              label: 'Bild',
              type: 'linked',
              template_name: 'Bild',
              validations: { max: 1 },
              ui: {
                edit: {
                  type: 'objectBrowser',
                  options: {
                    "data-validate": 'media',
                    "data-type": 'image'
                  }
                }
              }
            },
            video: {
              label: 'Video',
              type: 'linked',
              template_name: 'Video',
              validations: { max: 1 },
              ui: {
                edit: {
                  type: 'objectBrowser',
                  options: {
                    "data-validate": 'media',
                    "data-type": 'video'
                  }
                }
              }
            },
            mobile_application: {
              label: 'Link',
              type: 'embedded',
              template_name: 'MobileApplication',
              ui: {
                edit: {
                  type: 'embeddedObject'
                }
              }
            },
            topics: {
              label: 'Themenbereiche',
              type: 'classification',
              tree_label: 'Themenbereiche',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            markets: {
              label: 'Zielmarkt',
              type: 'classification',
              tree_label: 'Märkte',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            kind: {
              label: 'Inhaltsart',
              type: 'classification',
              tree_label: 'Inhaltsarten',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            season: {
              label: 'Jahreszeit',
              type: 'classification',
              tree_label: 'Jahreszeiten',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            state: {
              label: 'Bundesland',
              type: 'classification',
              tree_label: 'Bundesländer',
              ui: {
                edit: {
                  type: 'classificationSelector',
                  options: {
                    "data-validate": 'classification'
                  }
                }
              }
            },
            tags: {
              label: 'Tags',
              type: 'classification',
              tree_label: 'Tags',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            output_channels: {
              label: 'Ausgabekanäle',
              type: 'classification',
              tree_label: 'Ausgabekanäle',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            permitted_creator: {
              label: 'Ersteller',
              type: 'classification',
              tree_label: 'Ersteller',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            data_pool: {
              label: 'Inhaltspool',
              type: 'classification',
              tree_label: 'Inhaltspools',
              default_value: 'Aktuelle Inhalte'
            },
            data_type: {
              label: 'Inhaltstype',
              type: 'classification',
              tree_label: 'Inhaltstypen',
              default_value: 'App'
            },
            creator: {
              label: 'Ersteller',
              type: 'linked',
              template_name: 'Person'
            },
            date_created: {
              label: 'Erstellungsdatum',
              type: 'datetime',
              storage_location: 'value'
            },
            date_modified: {
              label: 'Änderungsdatum',
              type: 'datetime',
              storage_location: 'value'
            }
          }
        }
      }
    end

    let(:header_hash) do
      {
        data: {
          name: 'whatever',
          type: 'object',
          schema_type: 'CreativeWork',
          content_type: 'entity'
        }
      }
    end

    let(:simple_property_hash) do
      {
        label: 'whatever',
        type: 'string',
        storage_location: 'column',
        template_name: 'another_template'
      }
    end

    let(:classification_relation_hash) do
      {
        label: 'whatever',
        type: 'classification',
        tree_label: 'Inhaltspools',
        default_value: 'Aktuelle Inhalte'
      }
    end

    let(:embedded_object_hash) do
      {
        label: 'whatever',
        type: 'embedded',
        template_name: 'MobileApplication'
      }
    end

    let(:included_object_hash) do
      {
        label: 'whatever',
        type: 'object',
        storage_location: 'translated_value',
        properties: {
          propertyA: {
            label: 'label Property A',
            type: 'string',
            storage_location: 'translated_value'
          },
          propertyB: {
            label: 'label Property B',
            type: 'string',
            storage_location: 'translated_value'
          }
        }
      }
    end

    let(:computed_value_hash) do
      {
        label: 'whatever',
<<<<<<< HEAD
        type: 'computed',
=======
        type: 'number',
>>>>>>> old/develop
        storage_location: 'value',
        compute: {
          module: 'Utility::Compute::Math',
          method: 'sum',
<<<<<<< HEAD
          type: 'number',
=======
>>>>>>> old/develop
          parameters: {
            '0': 'label Property B',
            '1': 'string'
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
      assert !validate_header.call(test_hash).success?
    end

    it 'checks for presence of name attribute in header' do
      test_hash = {}
      test_hash[:data] = header_hash[:data].except(:name)
      assert !validate_header.call(test_hash).success?
    end

    it 'checks for valid value of type in header' do
      test_hash = header_hash
      test_hash[:data][:type] = nil
      assert !validate_header.call(test_hash).success?
    end

    it 'checks for wrong string value of type in header' do
      test_hash = header_hash
      test_hash[:data][:type] = 'string'
      assert !validate_header.call(test_hash).success?
    end

    it 'checks for presence of type attribute in header' do
      test_hash = {}
      test_hash[:data] = header_hash[:data].except(:type)
      assert !validate_header.call(test_hash).success?
    end

    it 'checks properties for presence of label' do
      test_hash = simple_property_hash.except(:label)
      assert !validate_property.call(test_hash).success?
    end

    it 'checks properties for label is a string' do
      test_hash = simple_property_hash
      test_hash[:label] = nil
      assert !validate_property.call(test_hash).success?
    end

    it 'checks properties for presence of type' do
      test_hash = simple_property_hash.except(:type)
      assert !validate_property.call(test_hash).success?
    end

    it 'checks properties for type is a string' do
      test_hash = simple_property_hash
      test_hash[:type] = nil
      assert !validate_property.call(test_hash).success?
    end

    it 'checks properties for type is a wrong string' do
      test_hash = simple_property_hash
      test_hash[:type] = 'long'
      assert !validate_property.call(test_hash).success?
    end

    it 'checks properties for valid types' do
      test_hash = simple_property_hash
      available_types = ['key', 'string', 'text', 'number', 'boolean', 'datetime', 'geographic', 'embedded', 'linked']
      available_types.each do |type_name|
        test_hash[:type] = type_name
        assert validate_property.call(test_hash).success?
      end
    end

    it 'checks properties for type object' do
      test_hash = simple_property_hash
      test_hash[:type] = 'object'
      test_hash[:storage_location] = 'value'
      test_hash[:properties] = { id: { label: 'id', type: 'key' } }
      assert validate_property.call(test_hash).success?
    end

    it 'checks properties for storage_location is a string' do
      test_hash = simple_property_hash
      test_hash[:storage_location] = nil
      assert !validate_property.call(test_hash).success?
    end

    it 'checks properties for storage_location is a wrong string' do
      test_hash = simple_property_hash
      test_hash[:storage_location] = 'long'
      assert !validate_property.call(test_hash).success?
    end

    it 'checks properties for valid storage_location' do
      test_hash = simple_property_hash
      available_storage_locations = ['column', 'value', 'translated_value']
      available_storage_locations.each do |storage_location|
        test_hash[:storage_location] = storage_location
        assert validate_property.call(test_hash).success?
      end
    end

    it 'checks correct classification_relation' do
      test_hash = classification_relation_hash
      assert validate_property.call(test_hash).success?
    end

    it 'checks classification_relation works without default_value' do
      test_hash = classification_relation_hash.except(:default_value)
      assert validate_property.call(test_hash).success?
    end

    it 'checks correct embedded_object_hash' do
      test_hash = embedded_object_hash
      assert validate_property.call(test_hash).success?
    end

    it 'checks included_object_hash correctly' do
      test_hash = included_object_hash
      assert validate_property.call(test_hash).success?
    end

    it 'checks included_object_hash for wrong type' do
      test_hash = included_object_hash
      test_hash[:type] = 'string'
      assert !validate_property.call(test_hash).success?
    end

    it 'checks included_object_hash for wrong storage_locations' do
      test_hash = included_object_hash
      (['key', 'column', 'classification_relation'] + ['things']).each do |location|
        test_hash[:storage_location] = location
        assert !validate_property.call(test_hash).success?
      end
    end

    it 'checks computed value definition' do
      test_hash = computed_value_hash
      assert validate_property.call(test_hash).success?
    end

    it 'checks computed value definition for non existing module' do
      test_hash = computed_value_hash
      test_hash[:compute][:module] = 'WhatEver'
      assert !validate_property.call(test_hash).success?
    end

    it 'checks computed value definition for non existing method' do
      test_hash = computed_value_hash
      test_hash[:compute][:method] = 'WhatEver'
      assert !validate_property.call(test_hash).success?
    end
<<<<<<< HEAD

    it 'checks computed value definition for non existing compute property hash' do
      test_hash = computed_value_hash
      test_hash.delete(:compute)
      assert !validate_property.call(test_hash).success?
    end

    it 'checks computed value definition for non existing target type' do
      test_hash = computed_value_hash
      test_hash[:compute][:type] = 'WhatEver'
      assert !validate_property.call(test_hash).success?
    end
=======
>>>>>>> old/develop
  end
end
