# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationByExternalKeyTest < DataCycleCore::V4::Base
          before(:all) do
            @external_system = DataCycleCore::ExternalSystem.first
            @classifications = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').classifications
            @external_keys = []
            @current_user = User.find_by(email: 'tester@datacycle.at')
            @current_user.update(access_token: SecureRandom.hex)

            @classifications.each.with_index do |c, index|
              key = "test-#{index}"
              c.update_columns(external_source_id: @external_system.id, external_key: key)
              c.primary_classification_alias.update_columns(external_source_id: @external_system.id)
              @external_keys << key
            end
          end

          test 'api/v4/external_sources/:external_source_id/concepts/:external_key with single key' do
            params = {
              external_source_id: @external_system.id,
              external_key: @external_keys.first,
              token: @current_user.access_token,
              include: 'identifier',
              page: {
                size: 100
              }
            }

            post api_v4_classification_trees_by_external_key_path(params)
            json_data = response.parsed_body

            assert_equal(1, json_data['@graph'].size)
            assert_equal(@external_system.identifier, json_data.dig('@graph', 0, 'identifier', 0, 'propertyID'))
            assert_equal(@external_keys.first, json_data.dig('@graph', 0, 'identifier', 0, 'value'))
          end

          test 'api/v4/external_sources/:external_source_id/concepts/:external_key with multiple keys' do
            params = {
              external_source_id: @external_system.id,
              external_key: @external_keys.join(','),
              token: @current_user.access_token,
              include: 'identifier',
              page: {
                size: 100
              }
            }

            post api_v4_classification_trees_by_external_key_path(params)
            json_data = response.parsed_body

            assert_equal(@external_keys.size, json_data['@graph'].size)
            json_data['@graph'].each do |item|
              assert(@external_keys.include?(item.dig('identifier', 0, 'value')))
              assert_equal(@external_system.identifier, item.dig('identifier', 0, 'propertyID'))
            end
          end
        end
      end
    end
  end
end
