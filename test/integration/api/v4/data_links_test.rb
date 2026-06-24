# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class DataLinksTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @user = User.find_by(email: 'tester@datacycle.at')
          @user.update_access_token!
          DataCycleCore::Thing.delete_all
          @routes = Engine.routes
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
        end

        test 'POST /api/v4/external_links/ with single valid' do
          post api_v4_data_links_path, params: {
            '@graph': [
              {
                receiver: {
                  email: 'receiver1@test.com',
                  givenName: 'Receiver',
                  familyName: 'One',
                  name: 'Receiver One'
                },
                item: {
                  '@id': @content.id,
                  '@type': 'Thing'
                },
                permission: 'read',
                comment: 'This is a test data link',
                validFrom: 1.day.ago.iso8601,
                validUntil: 7.days.from_now.iso8601
              }
            ]
          }, headers: {
            Authorization: "Bearer #{@user.access_token}"
          }

          assert_response :success
          assert_equal 'application/json; charset=utf-8', response.content_type
          json_data = response.parsed_body

          assert_equal 1, json_data['@graph'].size
          assert json_data['@graph'][0]['success']
          assert_predicate json_data['@graph'][0]['@id'], :present?
          assert_predicate json_data['@graph'][0]['url'], :present?
        end

        test 'POST /api/v4/external_links/ with multiple valid' do
          post api_v4_data_links_path, params: {
            '@graph': [
              {
                receiver: {
                  email: 'receiver1@test.com',
                  givenName: 'Receiver',
                  familyName: 'One',
                  name: 'Receiver One'
                },
                item: {
                  '@id': @content.id,
                  '@type': 'Thing'
                },
                permission: 'read',
                comment: 'This is a test data link',
                validFrom: 1.day.ago.iso8601,
                validUntil: 7.days.from_now.iso8601
              },
              {
                receiver: {
                  email: 'receiver2@test.com',
                  givenName: 'Receiver',
                  familyName: 'Two',
                  name: 'Receiver Two'
                },
                item: {
                  '@id': @content.id,
                  '@type': 'Thing'
                },
                permission: 'read',
                comment: 'This is a test data link',
                validFrom: 1.day.ago.iso8601,
                validUntil: 7.days.from_now.iso8601
              }
            ]
          }, headers: {
            Authorization: "Bearer #{@user.access_token}"
          }

          assert_response :success
          assert_equal 'application/json; charset=utf-8', response.content_type
          json_data = response.parsed_body

          assert_equal 2, json_data['@graph'].size
          assert json_data['@graph'][0]['success']
          assert json_data['@graph'][1]['success']
          assert_predicate json_data['@graph'][0]['@id'], :present?
          assert_predicate json_data['@graph'][0]['url'], :present?
          assert_predicate json_data['@graph'][1]['@id'], :present?
          assert_predicate json_data['@graph'][1]['url'], :present?
        end

        test 'POST /api/v4/external_links/ with mixed valid and invalid' do
          post api_v4_data_links_path, params: {
            '@graph': [
              {
                receiver: {
                  email: 'receiver1@test.com'
                },
                item: {
                  '@id': @content.id,
                  '@type': 'Thing'
                },
                permission: 'read',
                validUntil: 7.days.from_now.iso8601
              },
              {
                receiver: {
                  email: 'receiver2@test.com',
                  givenName: 'Receiver',
                  familyName: 'Two',
                  name: 'Receiver Two'
                },
                item: {
                  '@id': SecureRandom.uuid,
                  '@type': 'Thing'
                },
                permission: 'read',
                comment: 'This is a test data link',
                validFrom: 1.day.ago.iso8601,
                validUntil: 7.days.from_now.iso8601
              }
            ]
          }, headers: {
            Authorization: "Bearer #{@user.access_token}"
          }

          assert_response :success
          assert_equal 'application/json; charset=utf-8', response.content_type
          json_data = response.parsed_body

          assert_equal 2, json_data['@graph'].size
          assert json_data['@graph'][0]['success']
          assert_not json_data['@graph'][1]['success']
          assert_predicate json_data['@graph'][0]['@id'], :present?
          assert_predicate json_data['@graph'][0]['url'], :present?
        end

        test 'POST /api/v4/external_links/ forbidden permissions' do
          post api_v4_data_links_path, params: {
            '@graph': [
              {
                receiver: {
                  email: 'receiver1@test.com'
                },
                item: {
                  '@id': @content.id,
                  '@type': 'Thing'
                },
                permission: 'write'
              }
            ]
          }, headers: {
            Authorization: "Bearer #{@user.access_token}"
          }

          assert_response :success
          assert_equal 'application/json; charset=utf-8', response.content_type
          json_data = response.parsed_body

          assert_equal 1, json_data['@graph'].size
          assert json_data['@graph'][0]['success']
        end
      end
    end
  end
end
