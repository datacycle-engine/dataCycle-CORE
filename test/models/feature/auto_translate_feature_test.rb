# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AutoTranslateFeatureTest < ActiveSupport::TestCase
    test 'create poi in two languages with additional_infos' do
      content = @content = DataCycleCore::DummyDataHelper.create_data('poi1')
      translated_content = content.load_translated_content
      assert_equal(3, content.content_b.count)
      assert_equal(3, translated_content.map { |_, v| v.keys.count }.sum)
      assert_equal(additional_infos.keys, translated_content.keys)
    end

    test 'extract additional_translations from bilingual poi' do
      content = @content = DataCycleCore::DummyDataHelper.create_data('poi1')
      assert_equal(0, content.subject_of.count)

      update_info = content.create_update_translations
      assert_equal(create_update_response, update_info)
      assert_equal(2, content.subject_of.count)

      translation1 = content.subject_of.find_by(name: 'name1_de')
      assert_equal([:de, :en], translation1.available_locales)
      assert_equal('imported', translation1.translation_type)

      translation2 = content.subject_of.find_by(name: 'name2_de')
      assert_equal([:de], translation2.available_locales)
      assert_equal('imported', translation2.translation_type)

      # nothing left to do ... already updated
      assert_equal({}, content.create_update_translations)
    end

    test 'auto_translate remaining locales for translations' do
      content = @content = DataCycleCore::DummyDataHelper.create_data('poi1')
      content.create_update_translations
      translation_info = content.create_update_auto_translations
      assert_equal(translation_response, translation_info)

      translation2 = content.subject_of.find_by(name: 'name2_de')
      assert_equal([:de, :en], translation2.available_locales)
      assert_equal('imported', translation2.translation_type)

      I18n.with_locale(:en) do
        assert_equal('parking', translation2.name)
        assert_equal('en: source_locale=de', translation2.description)
        assert_equal('automatic', translation2.translation_type)
      end

      # nothing left to do ... already updated
      assert_equal({}, content.create_update_auto_translations)
    end

    test 'automatically set updated translations as manual updates' do
      content = @content = DataCycleCore::DummyDataHelper.create_data('poi1')
      content.create_update_translations
      translation = content.subject_of.find_by(name: 'name1_de')
      I18n.with_locale(:en) { translation.set_data_hash(data_hash: { 'description' => 'new_descriptions' }) }
      changed_data = I18n.with_locale(:en) { translation.get_data_hash }
      assert_equal('manual', changed_data.dig('translation_type'))
      assert_equal('Manuell', changed_data.dig('translated_classification').first.name)
    end

    test 'delete translations marked as manual updates' do
      content = @content = DataCycleCore::DummyDataHelper.create_data('poi1')
      content.create_update_translations
      translation = content.subject_of.find_by(name: 'name1_de')
      assert_equal(2, translation.available_locales.size)
      I18n.with_locale(:en) { translation.set_data_hash(data_hash: { 'description' => 'new_descriptions' }) }
      translation.destroy_auto_translations
      assert_equal(1, translation.available_locales.size)
      assert_equal(:de, translation.available_locales.first)
    end

    test 'delete thing if single translation marked as manual is deleted' do
      content = @content = DataCycleCore::DummyDataHelper.create_data('poi1')
      content.create_update_translations
      translation = content.subject_of.find_by(name: 'name2_de')
      assert_equal(1, translation.available_locales.size)
      translation.set_data_hash(data_hash: { 'description' => 'new_descriptions' })
      changed_data = translation.get_data_hash
      assert_equal('manual', changed_data.dig('translation_type'))
      assert_equal('Manuell', changed_data.dig('translated_classification').first.name)
      translation.destroy_auto_translations
      assert_raises ActiveRecord::RecordNotFound do
        translation.reload
      end
    end

    test 'destroy all translated_content' do
      content = @content = DataCycleCore::DummyDataHelper.create_data('poi1')
      content.create_update_translations
      assert_equal(2, content.subject_of.count)
      content.destroy_all_translated_content
      content.reload
      assert_equal(0, content.subject_of.count)
    end

    def additional_infos
      {
        'description' => {
          de: { name: 'name1_de', description: 'description1_de' },
          en: { name: 'name1_en', description: 'description1_en' }
        },
        'parking' => {
          de: { name: 'name2_de', description: 'description2_de' }
        }
      }
    end

    def create_update_response
      {
        'description' => [:de, :en],
        'parking' => [:de]
      }
    end

    def translation_response
      { 'parking' => [:en] }
    end
  end
end
