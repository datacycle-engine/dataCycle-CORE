# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedMulitLanguageTest < ActiveSupport::TestCase
        def setup
          DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').delete_all
          @embedded_multi = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Creative-Work-2', data_hash: { 'name' => 'Deutsch' }, prevent_history: true)
          I18n.with_locale(:en) { @embedded_multi.set_data_hash(data_hash: { 'name' => 'English' }, prevent_history: true) }

          @data_set_multi = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Creative-Work-2', data_hash: { 'name' => 'Deutsch' }, prevent_history: true)
          I18n.with_locale(:en) { @data_set_multi.set_data_hash(data_hash: { 'name' => 'English', 'embedded_creative_work' => [{ 'id' => @embedded_multi.id }] }, prevent_history: true) }

          assert_equal([:de, :en], @data_set_multi.available_locales.sort)
          assert_equal([:de, :en], @embedded_multi.available_locales.sort)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'delete object with embedded - one embedded in two languages' do
          data_set = @data_set_multi
          data_set.destroy_content(save_history: false)

          # check consistency of data in DB
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'delete object with embedded (language specific) - one embedded in two languages' do
          data_set = @data_set_multi
          data_set.destroy_content(save_history: false, destroy_locale: true)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'delete object with embedded (language specific, one by one) - one embedded in two languages' do
          data_set = @data_set_multi
          I18n.with_locale(:en) { data_set.destroy_content(save_history: false, destroy_locale: true) }

          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
          assert_equal(1, data_set.available_locales.size)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').first.available_locales.size)

          I18n.with_locale(:de) { data_set.destroy_content(save_history: false, destroy_locale: true) }

          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'add a new translation to main and a new translation to embedded' do
          data_set = @data_set_multi
          I18n.available_locales << :fr
          I18n.with_locale(:fr) { data_set.set_data_hash(data_hash: { 'name' => 'French', 'embedded_creative_work' => [{ 'id' => @embedded_multi.id, 'name' => 'French' }] }, prevent_history: true) }

          assert_equal([:de, :en, :fr], data_set.available_locales.sort)
          assert_equal([:de, :en, :fr], data_set.embedded_creative_work.first.available_locales.sort)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'add a new translation to main and a new embedded - old embedded deleted' do
          data_set = @data_set_multi
          I18n.available_locales << :fr
          I18n.with_locale(:fr) { data_set.set_data_hash(data_hash: { 'name' => 'French', 'embedded_creative_work' => [{ 'name' => 'French' }] }, prevent_history: true) }

          assert_equal([:de, :en, :fr], data_set.available_locales.sort)
          I18n.with_locale(:de) do
            assert_equal(1, data_set.embedded_creative_work.count) # default get data of any language
            assert_equal(1, data_set.load_embedded_objects('embedded_creative_work', nil, !data_set.properties_for('embedded_creative_work')&.dig('translated')).count) # default get data of any language
            assert_equal(0, data_set.load_relation('embedded_creative_work', nil, true, [I18n.locale]).count)
          end
          I18n.with_locale(:en) do
            assert_equal(1, data_set.embedded_creative_work.count)
            assert_equal(0, data_set.load_relation('embedded_creative_work', nil, true, [I18n.locale]).count)
          end
          I18n.with_locale(:fr) do
            assert_equal(1, data_set.embedded_creative_work.count)
            assert_equal(1, data_set.load_embedded_objects('embedded_creative_work').count)
            assert_equal(1, data_set.load_relation('embedded_creative_work', nil, true, [I18n.locale]).count)
            assert_equal([:fr], data_set.embedded_creative_work.first.available_locales.sort)
          end
          I18n.with_locale(:xx) do
            assert_equal(1, data_set.embedded_creative_work.count)
            assert_equal(1, data_set.load_embedded_objects('embedded_creative_work', nil, !data_set.properties_for('embedded_creative_work')&.dig('translated')).count)
            assert_equal(0, data_set.load_relation('embedded_creative_work', nil, true, [I18n.locale]).count)
          end

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'add a new embedded to main' do
          data_set = @data_set_multi
          I18n.with_locale(:en) do
            data_set.set_data_hash(
              data_hash: { 'name' => 'English', 'embedded_creative_work' => [{ 'id' => @embedded_multi.id }, { 'name' => 'English2' }] },
              prevent_history: true
            )
          end

          assert_equal(2, data_set.embedded_creative_work.count)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(2, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(2, DataCycleCore::ContentContent.count)
        end

        test 'replace old embedded with a new one, deletes all translations of old embedded' do
          data_set = @data_set_multi
          I18n.with_locale(:en) do
            data_set.set_data_hash(
              data_hash: { 'name' => 'English', 'embedded_creative_work' => [{ 'name' => 'English2' }] },
              prevent_history: true
            )
          end

          assert_equal(1, data_set.embedded_creative_work.count)
          I18n.with_locale(:en) { assert_equal('English2', data_set.embedded_creative_work.first.name) }

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        def teardown
          I18n.available_locales.delete(:fr)
        end
      end
    end
  end
end
