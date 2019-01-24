# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V3
      module Content
        module Extensions
          module CreativeWorks
            class Biography < ActionDispatch::IntegrationTest
              include Devise::Test::IntegrationHelpers
              include Engine.routes.url_helpers

              setup do
                @routes = Engine.routes

                image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
                @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

                person_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'api_person')
                gender_classification = DataCycleCore::Classification.find_by(name: 'Männlich')
                person_data_hash[:gender] = [gender_classification.id]
                person_data_hash[:image] = [@image.id]
                @person = DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: person_data_hash)

                organization_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('organizations', 'api_organization')
                organization_data_hash[:image] = [@image.id]
                @organization = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: organization_data_hash)

                place_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'api_poi')
                place_data_hash[:image] = @image.id
                @place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: place_data_hash)

                creative_work_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_article')
                creative_work_data_hash[:author] = @person.id
                creative_work_data_hash[:about] = @organization.id
                creative_work_data_hash[:image] = @image.id
                creative_work_data_hash[:content_location] = @place.id
                tag_classification = DataCycleCore::Classification.find_by(name: 'Tag 1')
                creative_work_data_hash[:tags] = [tag_classification.id]

                # validity_period
                validity_period = {
                  'valid_from' => 10.days.ago,
                  'valid_until' => 10.days.from_now
                }
                creative_work_data_hash[:validity_period] = validity_period

                @content = DataCycleCore::TestPreparations.create_content(template_name: 'Biografie', data_hash: creative_work_data_hash)

                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'json of stored article exists' do
                get api_v3_thing_path(@content)

                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body)

                # validate header
                assert_equal('http://schema.org', json_data.dig('@context'))
                assert_equal('CreativeWork', json_data.dig('@type'))
                assert_equal('Biografie', json_data.dig('contentType'))
                assert_equal(root_url[0...-1] + api_v3_thing_path(@content), json_data.dig('@id'))
                assert_equal(@content.id, json_data.dig('identifier'))
                assert_equal(@content.created_at.as_json, json_data.dig('dateCreated'))
                assert_equal(@content.updated_at.as_json, json_data.dig('dateModified'))
                assert_equal(root_url[0...-1] + thing_path(@content), json_data.dig('url'))

                # validity period
                # TODO: (move to generic tests)
                assert_equal(@content.validity_period.valid_from.to_date.as_json, json_data.dig('datePublished'))
                assert_equal(@content.validity_period.valid_until.to_date.as_json, json_data.dig('expires'))

                # classifications
                # TODO: (move to generic tests)
                assert(json_data.dig('classifications').present?)
                assert_equal(1, json_data.dig('classifications').size)
                classification_hash = json_data.dig('classifications').first
                assert_equal(['id', 'name', 'createdAt', 'updatedAt', 'ancestors'].sort, classification_hash.keys.sort)
                assert_equal('Biografie', classification_hash.dig('name'))
                assert_equal(2, classification_hash.dig('ancestors').size)
                assert_equal(['Inhaltstypen', 'Text'], classification_hash.dig('ancestors').map { |item| item.dig('name') }.sort)

                # language
                assert_equal('de', json_data.dig('inLanguage'))

                # content data
                assert_equal(@content.name, json_data.dig('headline'))
                assert_equal(@content.description, json_data.dig('description'))
                assert_equal(@content.text, json_data.dig('text'))
                assert_equal(@content.alternative_headline, json_data.dig('alternativeHeadline'))
                assert_equal(@content.link_name, json_data.dig('name'))
                assert_equal(@content.url, json_data.dig('sameAs'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, json_data.dig('image').first.dig('identifier'))
                assert_equal(@content.author.first.id, json_data.dig('author').first.dig('identifier'))
                assert_equal(@content.about.first.id, json_data.dig('about').first.dig('identifier'))
                assert_equal(@content.content_location.first.id, json_data.dig('contentLocation').first.dig('identifier'))

                # check for tag classification and keyword transformation
                # TODO: (move to Transformations tests)
                # API: Transformation: Classification.keywords
                assert_equal(@content.tags.first.name, json_data.dig('tags').first.dig('name'))
                assert_equal(@content.tags.first.name, json_data.dig('keywords'))
                assert_equal(@content.keywords, json_data.dig('keywords'))
              end

              test 'stored item can be found via different endpoints' do
                get(api_v3_things_path)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body).dig('data').select { |item| item.dig('contentType') == 'Biografie' }.first
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_contents_search_path)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body).dig('data').select { |item| item.dig('contentType') == 'Biografie' }.first
                assert_equal(@content.id, json_data.dig('identifier'))

                get(api_v3_creative_works_path)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                json_data = JSON.parse(response.body).dig('data').select { |item| item.dig('contentType') == 'Biografie' }.first
                assert_equal(@content.id, json_data.dig('identifier'))
              end

              test 'APIv2 json equals APIv3 json result' do
                get api_v2_thing_path(@content)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                api_v2_json = JSON.parse(response.body)

                get api_v3_thing_path(@content)
                assert_response(:success)
                assert_equal('application/json', response.content_type)
                api_v3_json = JSON.parse(response.body)

                excepted_params = ['@id', 'author', 'about', 'image', 'contentLocation']

                assert_equal(api_v3_json.except(*excepted_params), api_v2_json.except(*excepted_params))
                assert_equal(api_v3_json.dig('author').first.except(*excepted_params), api_v2_json.dig('author').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('about').first.except(*excepted_params), api_v2_json.dig('about').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('image').first.except(*excepted_params), api_v2_json.dig('image').first.except(*excepted_params))
                assert_equal(api_v3_json.dig('contentLocation').first.except(*excepted_params), api_v2_json.dig('contentLocation').first.except(*excepted_params))
              end
            end
          end
        end
      end
    end
  end
end
