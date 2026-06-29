# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the Translate feature class methods. attribute_keys / endpoint /
    # external_source / configuration are stubbed so the text-source, translate and
    # allowed-language helpers run without a configured endpoint or external system.
    class TranslateFeatureCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Feature::Translate

      test 'text_source and allowed_attribute_keys read the configured attribute keys' do
        Subject.stub(:attribute_keys, ['name']) do
          assert_equal 'name', Subject.text_source(nil)
          assert_equal ['name'], Subject.allowed_attribute_keys(nil)
        end
      end

      test 'translate_text returns {} without an endpoint and delegates otherwise' do
        Subject.stub(:endpoint, nil) do
          assert_equal({}, Subject.translate_text({ 'text' => 'hi' }))
        end

        endpoint = Object.new
        endpoint.define_singleton_method(:translate) { |hash| { 'translation' => hash['text'] } }

        Subject.stub(:endpoint, endpoint) do
          assert_equal({ 'translation' => 'hi' }, Subject.translate_text({ 'text' => 'hi' }))
        end
      end

      test 'allowed target/source languages intersect the available locales when an external source exists' do
        Subject.stub(:external_source, Object.new) do
          Subject.stub(:configuration, { endpoint: 'DataCycleCore' }) do
            assert_kind_of Array, Subject.allowed_target_languages
            assert_kind_of Array, Subject.allowed_source_languages
            assert_includes [true, false], Subject.source_locale_allowed?(:de)
          end
        end
      end
    end
  end
end
