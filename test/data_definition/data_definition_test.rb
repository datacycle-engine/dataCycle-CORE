require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::ImportTemplates do
  subject do
    DataCycleCore::MasterData::ImportTemplates
  end

  describe 'loaded template_data' do
    let(:data_template) do
      {
        data: {
          name: 'App',
          type: 'object',
          content_type: 'entity',
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
              storage_location: 'content',
              search: true,
              validations: { minLength: 1 }
            },
            validity_period: {
              label: 'Gültigkeitszeitraum',
              type: 'object',
              storage_location: 'metadata',
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
                  type: 'date_time',
                  storage_location: 'metadata',
                  validations: { format: 'date_time' },
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
                  type: 'string',
                  storage_location: 'metadata',
                  validations: { format: 'date_time' },
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
              storage_location: 'content',
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
              linked_table: 'creative_works',
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
              linked_table: 'creative_works',
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
              linked_table: 'creative_works',
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
              classification_tree: 'Themenbereiche',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            markets: {
              label: 'Zielmarkt',
              type: 'classification',
              classification_tree: 'Märkte',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            kind: {
              label: 'Inhaltsart',
              type: 'classification',
              classification_tree: 'Inhaltsarten',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            season: {
              label: 'Jahreszeit',
              type: 'classification',
              classification_tree: 'Jahreszeiten',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            state: {
              label: 'Bundesland',
              type: 'classification',
              classification_tree: 'Bundesländer',
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
              classification_tree: 'Tags',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            output_channels: {
              label: 'Ausgabekanäle',
              type: 'classification',
              classification_tree: 'Ausgabekanäle',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            permitted_creator: {
              label: 'Ersteller',
              type: 'classification',
              classification_tree: 'Ersteller',
              ui: {
                edit: {
                  type: 'classificationSelector'
                }
              }
            },
            data_pool: {
              label: 'Inhaltspool',
              type: 'classification',
              classification_tree: 'Inhaltspools',
              default_value: 'Aktuelle Inhalte'
            },
            data_type: {
              label: 'Inhaltstype',
              type: 'classification',
              classification_tree: 'Inhaltstypen',
              default_value: 'App'
            },
            creator: {
              label: 'Ersteller',
              type: 'linked',
              linked_table: 'users'
            },
            date_created: {
              label: 'Erstellungsdatum',
              type: 'date_time',
              storage_location: 'metadata'
            },
            date_modified: {
              label: 'Änderungsdatum',
              type: 'date_time',
              storage_location: 'metadata'
            }
          }
        }
      }
    end

    let(:header_hash) do
      {
        data: {
          name: 'whatever',
          type: 'object'
        }
      }
    end

    let(:simple_property_hash) do
      {
        label: 'whatever',
        type: 'string',
        storage_location: 'column'
      }
    end

    let(:classification_relation_hash) do
      {
        label: 'whatever',
        type: 'classification',
        classification_tree: 'Inhaltspools',
        default_value: 'Aktuelle Inhalte'
      }
    end

    let(:embedded_object_hash) do
      {
        label: 'whatever',
        type: 'embedded',
        linked_table: 'creative_works',
        template_name: 'MobileApplication'
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
            storage_location: 'metadata'
          },
          propertyB: {
            label: 'label Property B',
            type: 'string',
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
      assert !subject.validate_header.call(test_hash).success?
    end

    it 'checks for presence of name attribute in header' do
      test_hash = {}
      test_hash[:data] = header_hash[:data].except(:name)
      assert !subject.validate_header.call(test_hash).success?
    end

    it 'checks for valid value of type in header' do
      test_hash = header_hash
      test_hash[:data][:type] = nil
      assert !subject.validate_header.call(test_hash).success?
    end

    it 'checks for wrong string value of type in header' do
      test_hash = header_hash
      test_hash[:data][:type] = 'string'
      assert !subject.validate_header.call(test_hash).success?
    end

    it 'checks for presence of type attribute in header' do
      test_hash = {}
      test_hash[:data] = header_hash[:data].except(:type)
      assert !subject.validate_header.call(test_hash).success?
    end

    it 'checks properties for presence of label' do
      test_hash = simple_property_hash.except(:label)
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks properties for label is a string' do
      test_hash = simple_property_hash
      test_hash[:label] = nil
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks properties for presence of type' do
      test_hash = simple_property_hash.except(:type)
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks properties for type is a string' do
      test_hash = simple_property_hash
      test_hash[:type] = nil
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks properties for type is a wrong string' do
      test_hash = simple_property_hash
      test_hash[:type] = 'long'
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks properties for valid types' do
      test_hash = simple_property_hash
      available_types = ['key', 'string', 'text', 'number', 'date_time', 'geographic', 'object', 'embedded', 'linked', 'classification']
      available_types.each do |type_name|
        test_hash[:type] = type_name
        assert subject.validate_property.call(test_hash).success?
      end
    end

    it 'checks properties for storage_location is a string' do
      test_hash = simple_property_hash
      test_hash[:storage_location] = nil
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks properties for storage_location is a wrong string' do
      test_hash = simple_property_hash
      test_hash[:storage_location] = 'long'
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks properties for valid storage_location' do
      test_hash = simple_property_hash
      available_storage_locations = ['column', 'metadata', 'content']
      available_storage_locations.each do |storage_location|
        test_hash[:storage_location] = storage_location
        assert subject.validate_property.call(test_hash).success?
      end
    end

    it 'checks correct classification_relation' do
      test_hash = classification_relation_hash
      assert subject.validate_property.call(test_hash).success?
    end

    # TODO: add type_name validation after polymorphic relation tables
    # (see models/data_cycle_core/master_data/import_templates.rb)
    # it 'checks classification_relation for presence of type_name' do
    #   test_hash = classification_relation_hash.except(:type_name)
    #   assert !subject.validate_property.call(test_hash).success?
    # end

    it 'checks classification_relation works without default_value' do
      test_hash = classification_relation_hash.except(:default_value)
      assert subject.validate_property.call(test_hash).success?
    end

    # default_value not checked at the moment
    # it 'checks classification_relation error for wrong default_value' do
    #   test_hash = classification_relation_hash
    #   test_hash[:default_value] = 'wrong name'
    #   assert !subject.validate_property.call(test_hash).success?
    # end

    it 'checks correct embedded_object_hash' do
      test_hash = embedded_object_hash
      assert subject.validate_property.call(test_hash).success?
    end

    it 'checks included_object_hash correctly' do
      test_hash = included_object_hash
      assert subject.validate_property.call(test_hash).success?
    end

    it 'checks included_object_hash for wrong type' do
      test_hash = included_object_hash
      test_hash[:type] = 'string'
      assert !subject.validate_property.call(test_hash).success?
    end

    it 'checks included_object_hash for wrong storage_locations' do
      test_hash = included_object_hash
      (['key', 'column', 'classification_relation'] + DataCycleCore.content_tables).each do |location|
        test_hash[:storage_location] = location
        assert !subject.validate_property.call(test_hash).success?
      end
    end
  end
end
