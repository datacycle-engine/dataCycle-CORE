# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class ExternalIdentifierUrlTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          before(:all) do
            @routes = Engine.routes

            @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
            # configured at root level, so it applies to the primary source (import) and to syncs (export) alike
            @external_system.update!(default_options: { 'external_detail_url' => 'https://test.at/%<locale>s/detail/%<external_key>s' })
            @external_system_without_url = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system-2')

            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => 'external identifier url' })
            I18n.with_locale(:en) { @content.set_data_hash(data_hash: { 'name' => 'external identifier url (en)' }, partial_update: true, prevent_history: true) }
            @content.update!(external_source_id: @external_system.id, external_key: 'primary-key')
            @content.add_external_system_data(@external_system, nil, 'success', 'link', 'sync-key')
            @content.add_external_system_data(@external_system_without_url, nil, 'success', 'link', 'no-url-key')
            @content.reload
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          def load_identifiers(language = nil)
            get api_v4_thing_path({ id: @content.id, fields: 'identifier', language: }.compact)

            assert_response(:success)
            response.parsed_body.dig('@graph', 0, 'identifier')
          end

          test 'primary external source exposes the configured external detail url' do
            identifier = load_identifiers.detect { |i| i['value'] == 'primary-key' }

            assert_equal(
              {
                '@type' => 'PropertyValue',
                'propertyID' => 'remote-system',
                'value' => 'primary-key',
                'valueReference' => 'import',
                'url' => 'https://test.at/de/detail/primary-key'
              },
              identifier
            )
          end

          test 'external system sync exposes the configured external detail url' do
            identifier = load_identifiers.detect { |i| i['value'] == 'sync-key' }

            assert_equal(
              {
                '@type' => 'PropertyValue',
                'propertyID' => 'remote-system',
                'value' => 'sync-key',
                'valueReference' => 'link',
                'url' => 'https://test.at/de/detail/sync-key'
              },
              identifier
            )
          end

          test 'external system without external_detail_url exposes no url' do
            identifier = load_identifiers.detect { |i| i['value'] == 'no-url-key' }

            assert_equal(
              {
                '@type' => 'PropertyValue',
                'propertyID' => 'remote-system-2',
                'value' => 'no-url-key',
                'valueReference' => 'link'
              },
              identifier
            )
          end

          test 'external detail url is rendered for the requested language' do
            identifiers = load_identifiers('en')

            assert_equal('https://test.at/en/detail/primary-key', identifiers.detect { |i| i['value'] == 'primary-key' }['url'])
            assert_equal('https://test.at/en/detail/sync-key', identifiers.detect { |i| i['value'] == 'sync-key' }['url'])
          end
        end
      end
    end
  end
end
