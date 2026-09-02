# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    class ExternalSystemSyncTest < ActiveSupport::TestCase
      def setup
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' }, prevent_history: true)
        @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      end

      test 'test external_url in export_config with external_key in external_system_sync' do
        @external_system.update(default_options: {
          export: {
            external_url: 'https://test.at/%<external_key>s/%<locale>s/%<type>s/edit'
          }
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'link', 'test-link-1')

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-1/#{locale}/artikel/edit", @content.external_system_syncs.first.external_url
          end
        end
      end

      test 'test external_detail_url in export_config with external_key in external_system_sync' do
        @external_system.update(default_options: {
          export: {
            external_detail_url: 'https://test.at/%<external_key>s/%<locale>s/%<type>s'
          }
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'export', 'test-link-1')

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-1/#{locale}/artikel", @content.external_system_syncs.first.external_detail_url
          end
        end
      end

      test 'test external_detail_url is read for the sync_type of the sync, not for :export' do
        # the outdooractive connector ships external_detail_url in the import config only
        @external_system.update(default_options: {
          import: {
            external_detail_url: 'https://test.at/import/%<external_key>s'
          },
          export: {
            external_detail_url: 'https://test.at/export/%<external_key>s'
          }
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'import', 'test-import')
        @content.add_external_system_data(@external_system, nil, 'success', 'export', 'test-export')

        syncs = @content.external_system_syncs.index_by(&:sync_type)

        assert_equal('https://test.at/import/test-import', syncs['import'].external_detail_url)
        assert_equal('https://test.at/export/test-export', syncs['export'].external_detail_url)
      end

      test 'test external_detail_url is blank for a sync_type without a configured template' do
        @external_system.update(default_options: {
          import: {
            external_detail_url: 'https://test.at/import/%<external_key>s'
          }
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'export', 'test-export')

        assert_nil(@content.external_system_syncs.first.external_detail_url)
      end

      test 'test external_detail_url falls back to the root config for sync_types without their own section' do
        @external_system.update(default_options: {
          external_detail_url: 'https://test.at/%<external_key>s'
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'duplicate', 'test-duplicate')

        assert_equal('https://test.at/test-duplicate', @content.external_system_syncs.first.external_detail_url)
      end

      test 'test a malformed external_detail_url template is treated like a missing one' do
        @content.add_external_system_data(@external_system, nil, 'success', 'export', 'test-link-1')
        @content.update(external_source_id: @external_system.id, external_key: 'test-link-2')

        [
          'https://test.at/%<unknown_placeholder>s/%<external_key>s', # KeyError
          'https://test.at/search?q=a%20b&id=%<external_key>s' # TypeError
        ].each do |template|
          @external_system.update(default_options: { external_detail_url: template })
          # reload the whole content so external_source / external_system are fresh instances
          # (ExternalSystem memoizes default_options, so #reload alone would keep the old config)
          content = DataCycleCore::Thing.find(@content.id)

          assert_nil(content.external_system_syncs.first.external_detail_url, template)
          assert_nil(content.external_source.external_detail_url(content), template)
        end
      end

      test 'test external_url in import_config with external_key as external_source' do
        @content.update(external_source_id: @external_system.id, external_key: 'test-link-1')

        @external_system.update(default_options: {
          import: {
            external_url: 'https://test.at/%<external_key>s/%<locale>s/edit'
          }
        })

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-1/#{locale}/edit", @content.external_source.external_url(@content)
          end
        end
      end

      test 'test external_detail_url in import_config with external_key as external_source' do
        @content.update(external_source_id: @external_system.id, external_key: 'test-link-1')

        @external_system.update(default_options: {
          import: {
            external_detail_url: 'https://test.at/%<external_key>s/%<locale>s'
          }
        })

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-1/#{locale}", @content.external_source.external_detail_url(@content)
          end
        end
      end

      test 'test external_url in default_config' do
        @external_system.update(default_options: {
          external_url: 'https://test.at/%<external_key>s/%<locale>s/edit'
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'link', 'test-link-1')
        @content.update(external_source_id: @external_system.id, external_key: 'test-link-2')

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-1/#{locale}/edit", @content.external_system_syncs.first.external_url
            assert_equal "https://test.at/test-link-2/#{locale}/edit", @content.external_source.external_url(@content)
          end
        end
      end

      test 'test external_detail_url in default_config' do
        @external_system.update(default_options: {
          external_detail_url: 'https://test.at/%<external_key>s/%<locale>s'
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'link', 'test-link-1')
        @content.update(external_source_id: @external_system.id, external_key: 'test-link-2')

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-1/#{locale}", @content.external_system_syncs.first.external_detail_url
            assert_equal "https://test.at/test-link-2/#{locale}", @content.external_source.external_detail_url(@content)
          end
        end
      end

      test 'test external_url in export_config with custom attribute as external_key in external_system_sync' do
        @external_system.update(default_options: {
          export: {
            external_url: 'https://test.at/%<external_key>s/%<locale>s/%<type>s/edit',
            external_key_param: 'super_external_name'
          }
        })
        @content.add_external_system_data(@external_system, { super_external_name: 'test-link-2' }, 'success', 'link')

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-2/#{locale}/artikel/edit", @content.external_system_syncs.first.external_url
          end
        end
      end

      test 'test external_url directly in external_system_sync' do
        @content.add_external_system_data(@external_system, { external_url: 'https://www.test.at/test-link-2' }, 'success', 'link')

        assert_equal 'https://www.test.at/test-link-2', @content.external_system_syncs.first.external_url
      end

      test 'test external_detail_url as url in external_syncs_as_property_values' do
        @external_system.update(default_options: {
          external_detail_url: 'https://test.at/%<locale>s/%<external_key>s'
        })
        @content.add_external_system_data(@external_system, nil, 'success', 'link', 'test-link-1')
        @content.update(external_source_id: @external_system.id, external_key: 'test-link-2')

        I18n.with_locale(:de) do
          assert_equal(
            [
              { '@type' => 'PropertyValue', 'propertyID' => @external_system.identifier, 'value' => 'test-link-2', 'valueReference' => 'import', 'url' => 'https://test.at/de/test-link-2' },
              { '@type' => 'PropertyValue', 'propertyID' => @external_system.identifier, 'value' => 'test-link-1', 'valueReference' => 'link', 'url' => 'https://test.at/de/test-link-1' }
            ],
            @content.external_syncs_as_property_values
          )
        end
      end

      test 'test external_syncs_as_property_values without configured external_detail_url' do
        @external_system.update(default_options: {})
        @content.add_external_system_data(@external_system, nil, 'success', 'link', 'test-link-1')
        @content.update(external_source_id: @external_system.id, external_key: 'test-link-2')

        assert_equal(
          [
            { '@type' => 'PropertyValue', 'propertyID' => @external_system.identifier, 'value' => 'test-link-2', 'valueReference' => 'import' },
            { '@type' => 'PropertyValue', 'propertyID' => @external_system.identifier, 'value' => 'test-link-1', 'valueReference' => 'link' }
          ],
          @content.external_syncs_as_property_values
        )
      end
    end
  end
end
