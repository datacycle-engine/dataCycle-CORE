# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class EmbeddedMulitSingleLanguageTest < ActiveSupport::TestCase
        def setup
          embedded_de = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Creative-Work-2', data_hash: { 'name' => 'Deutsch' }, prevent_history: true)
          embedded_en = nil
          I18n.with_locale(:en) do
            embedded_en = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Creative-Work-2', data_hash: { 'name' => 'English' }, prevent_history: true)
          end

          @data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Creative-Work-1', data_hash: { 'name' => 'Deutsch', 'embedded_creative_work' => [{ 'id' => embedded_de.id }] }, prevent_history: true)
          I18n.with_locale(:en) { @data_set.set_data_hash(data_hash: { 'name' => 'English', 'embedded_creative_work' => [{ 'id' => embedded_en.id }] }, prevent_history: true) }

          assert_equal([:de, :en], @data_set.available_locales.sort)
          assert_equal([:de], embedded_de.available_locales)
          assert_equal([:en], embedded_en.available_locales)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(2, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(2, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded - 2 embedded in different languages' do
          data_set = @data_set
          data_set.destroy_content(save_history: false)

          # check consistency of data in DB
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded (language specific) - 2 embedded in different languages' do
          data_set = @data_set
          data_set.destroy_content(save_history: false, destroy_locale: true)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
        end

        test 'delete object with emedded (language specific, one by one) - 2 embedded in different languages' do
          data_set = @data_set
          I18n.with_locale(:en) { data_set.destroy_content(save_history: false, destroy_locale: true) }

          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(1, DataCycleCore::ContentContent.count)
          assert_equal(1, data_set.available_locales.size)
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').first.available_locales.size)

          I18n.with_locale(:de) { data_set.destroy_content(save_history: false, destroy_locale: true) }

          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(0, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(0, DataCycleCore::ContentContent.count)
        end

        test 'add a new translation to main and a new embedded in the new language' do
          data_set = @data_set

          I18n.available_locales << :fr
          I18n.with_locale(:fr) { data_set.set_data_hash(data_hash: { 'name' => 'French', 'embedded_creative_work' => [{ 'name' => 'French' }] }, prevent_history: true) }
          assert_equal([:de, :en, :fr], data_set.available_locales.sort)
          assert_equal(3, data_set.load_relation('embedded_creative_work', nil, false, [I18n.locale]).size)

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(3, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(3, DataCycleCore::ContentContent.count)
        end

        test 'add a new embedded in one language to main' do
          data_set = @data_set
          I18n.with_locale(:en) do
            embedded_en = data_set.embedded_creative_work.first
            data_set.set_data_hash(data_hash: { 'name' => 'English2', 'embedded_creative_work' => [{ 'id' => embedded_en.id }, { 'name' => 'English2' }] }, prevent_history: true)
          end

          assert_equal([:de, :en], data_set.available_locales.sort)
          assert_equal(3, data_set.load_relation('embedded_creative_work', nil, false, [I18n.locale]).size)
          assert_equal(1, data_set.embedded_creative_work.size)
          I18n.with_locale(:en) { assert_equal(2, data_set.embedded_creative_work.size) }

          # check consistency of data in DB
          assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Entity-Creative-Work-1').count)
          assert_equal(3, DataCycleCore::Thing.where(template: false, template_name: 'Embedded-Creative-Work-2').count)
          assert_equal(3, DataCycleCore::ContentContent.count)
        end

        def teardown
          I18n.available_locales.delete(:fr)
        end
      end
    end
  end
end
