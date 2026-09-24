# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module MediaObjects
            # #47881: the generated ALT label is a second attribute next to the editorial one, so a
            # description a redaction wrote is never overwritten. Both are delivered as
            # `description`, and which one the API answers with is decided purely by their order in
            # the template: properties are serialized in that order, a blank value is skipped, and
            # the later one overwrites the earlier. That makes the generated attribute's
            # `:position: :before: description` load-bearing rather than cosmetic.
            class GeneratedDescriptionTest < DataCycleCore::V4::Base
              GENERATED = 'Ein Feld voller Lavendel, generiert'
              EDITORIAL = 'Lavendelfeld bei Sonnenuntergang'

              def image(data_hash)
                DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'GeneratedDescription' }.merge(data_hash))
              end

              def api_description(content)
                post api_v4_thing_path(id: content.id)

                assert_response :success
                response.parsed_body['@graph'].first['description']
              end

              test 'the generated description is delivered while the editorial one is blank' do
                content = image(description_generated: GENERATED)

                assert_equal GENERATED, api_description(content)
              end

              test 'the editorial description wins over the generated one' do
                content = image(description_generated: GENERATED, description: EDITORIAL)

                assert_equal EDITORIAL, api_description(content)
              end

              test 'an image without either has no description at all' do
                assert_nil api_description(image({}))
              end

              test 'the generated attribute is not importable, so an import cannot overwrite it' do
                template = DataCycleCore::Thing.new(template_name: 'Bild')

                assert_includes template.local_property_names, 'description_generated'
                assert_not_includes template.importable_property_names, 'description_generated'
                assert_includes template.importable_property_names, 'description'
              end
            end
          end
        end
      end
    end
  end
end
