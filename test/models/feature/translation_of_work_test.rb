# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TranslationOfWorkTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })
    end

    test 'set translation_of_work correctly for new locale' do
      I18n.with_locale(:en) do
        content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 2 en' }, source: @content)

        assert_equal [@content.id], content2.try(DataCycleCore::Feature::TranslationOfWork.attribute_keys.first).pluck(:id)
        assert_equal [content2.id], @content.try(@content.property_definitions.find { |_k, v| v['inverse_of'] == DataCycleCore::Feature::TranslationOfWork.attribute_keys.first }.first).pluck(:id)
      end
    end

    test 'dont set translation_of_work if locale is same' do
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 2' }, source: @content)

      assert_empty content2.try(DataCycleCore::Feature::TranslationOfWork.attribute_keys.first).pluck(:id)
      assert_empty @content.try(@content.property_definitions.find { |_k, v| v['inverse_of'] == DataCycleCore::Feature::TranslationOfWork.attribute_keys.first }.first).pluck(:id)
    end
  end
end
