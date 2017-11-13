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

    it 'generates a validator' do
      assert subject.validate_header.(data_template).success?
    end

    it 'checks all attributes' do
      subject.validate(data_template)

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

  end
end
