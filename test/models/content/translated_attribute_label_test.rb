# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

module DataCycleCore
  module Content
    class TranslatedAttributeLabelTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @content = DataCycleCore::Thing.find_by(template: true, template_name: 'Artikel')
      end

      test 'human_attribute_name for different languages' do
        get_translation = ->(_key, args) { "test #{args[:locale]}" }

        I18n.stub :exists?, true do
          I18n.stub :t, get_translation do
            I18n.with_locale(:en) do
              assert_equal('test de', DataCycleCore::Thing.human_attribute_name(:name, locale: :de, base: @content))
            end

            I18n.with_locale(:de) do
              assert_equal('test de', DataCycleCore::Thing.human_attribute_name(:name, locale: :de, base: @content))
            end

            I18n.with_locale(:en) do
              assert_equal('test en', DataCycleCore::Thing.human_attribute_name(:name, locale: :en, base: @content))
            end

            I18n.with_locale(:de) do
              assert_equal('test en', DataCycleCore::Thing.human_attribute_name(:name, locale: :en, base: @content))
            end
          end
        end
      end

      test 'human_property_name for different languages' do
        get_translation = ->(_key, args) { "test #{args[:locale]}" }

        I18n.stub :exists?, true do
          I18n.stub :t, get_translation do
            I18n.with_locale(:en) do
              assert_equal('test de', DataCycleCore::Thing.human_property_name(:name, locale: :de, base: @content))
            end

            I18n.with_locale(:de) do
              assert_equal('test de', DataCycleCore::Thing.human_property_name(:name, locale: :de, base: @content))
            end

            I18n.with_locale(:en) do
              assert_equal('test en', DataCycleCore::Thing.human_property_name(:name, locale: :en, base: @content))
            end

            I18n.with_locale(:de) do
              assert_equal('test en', DataCycleCore::Thing.human_property_name(:name, locale: :en, base: @content))
            end
          end
        end
      end
    end
  end
end
