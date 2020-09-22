# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    class ExternalSystemSyncTest < ActiveSupport::TestCase
      def setup
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' }, prevent_history: true)
        @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'Local-Text-File')
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
        @content.add_external_system_data(@external_system, nil, 'success', 'link', 'test-link-1')

        I18n.available_locales.each do |locale|
          I18n.with_locale(locale) do
            assert_equal "https://test.at/test-link-1/#{locale}/artikel", @content.external_system_syncs.first.external_detail_url
          end
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
    end
  end
end
