# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Templates::TemplateValidator do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Templates::TemplateValidator
  end

  let(:validate_property) do
    DataCycleCore::MasterData::Templates::TemplatePropertyContract.new
  end

  let(:validate_header) do
    DataCycleCore::MasterData::Templates::TemplateHeaderContract.new
  end

  describe 'loaded template_data' do
    let(:data_template) do
      {
        name: 'App',
        set: 'creative_works',
        path: '',
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
              storage_location: 'translated_value',
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
              storage_location: 'translated_value',
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
                    'data-validate': 'media',
                    'data-type': 'image'
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
                    'data-validate': 'media',
                    'data-type': 'video'
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
                    'data-validate': 'classification'
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

    let(:video) do
      {
        name: 'Video',
        set: 'media_objects',
        path: '',
        data: {
          name: 'Video',
          type: 'object',
          content_type: 'entity',
          schema_type: 'MediaObject',
          boost: 10.0,
          properties: {
            id: {
              label: 'id',
              type: 'key'
            }
          }
        }
      }
    end

    let(:bild) do
      {
        name: 'Bild',
        set: 'media_objects',
        path: '',
        data: {
          name: 'Bild',
          type: 'object',
          content_type: 'entity',
          schema_type: 'MediaObject',
          boost: 10.0,
          properties: {
            id: {
              label: 'id',
              type: 'key'
            }
          }
        }
      }
    end

    let(:mobile_application) do
      {
        name: 'MobileApplication',
        set: 'media_objects',
        path: '',
        data: {
          name: 'MobileApplication',
          type: 'object',
          content_type: 'entity',
          schema_type: 'MediaObject',
          boost: 10.0,
          properties: {
            id: {
              label: 'id',
              type: 'key'
            },
            name: {
              label: 'Name',
              type: 'string',
              storage_location: 'translated_value'
            }
          }
        }
      }
    end

    let(:person) do
      {
        name: 'Person',
        set: 'media_objects',
        path: '',
        data: {
          name: 'Person',
          type: 'object',
          content_type: 'entity',
          schema_type: 'MediaObject',
          boost: 10.0,
          properties: {
            id: {
              label: 'id',
              type: 'key'
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

    it 'check a complex data_template' do
      validator = subject.new(templates: { creative_works: [
        data_template,
        video,
        bild,
        mobile_application,
        person
      ] }.with_indifferent_access)
      errors = validator.validate
      assert_equal [], errors
    end

    it 'checks for valid value of name attribute in header' do
      test_hash = header_hash
      test_hash[:data][:name] = nil
      assert_not validate_header.call(test_hash).success?
    end
  end
end
