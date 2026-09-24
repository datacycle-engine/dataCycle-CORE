# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module Config
      # Verifies that OpenapiController restricts the `language` query parameter to the
      # instance's configured locales instead of passing arbitrary values through to I18n.
      class OpenapiTest < ActiveSupport::TestCase
        # Resolves the controller's private `locale` for a given raw `language` param value.
        def resolved_locale(value)
          controller = DataCycleCore::Api::Config::OpenapiController.new
          controller.params = ActionController::Parameters.new(value.nil? ? {} : { language: value })
          controller.remove_instance_variable(:@permitted_params) if controller.instance_variable_defined?(:@permitted_params)
          controller.send(:locale)
        end

        test 'supported languages are used as requested' do
          I18n.available_locales.each do |locale|
            assert_equal locale, resolved_locale(locale.to_s)
          end
        end

        test 'a missing or blank language falls back to the default locale' do
          assert_equal I18n.default_locale, resolved_locale(nil)
          assert_equal I18n.default_locale, resolved_locale('')
        end

        test 'unsupported and malicious language values are restricted to the default locale' do
          ['zz', 'de-DE', 'EN', '../../etc/passwd', 'en; DROP TABLE things', '123'].each do |value|
            next if I18n.available_locales.include?(value.to_sym)

            assert_equal I18n.default_locale, resolved_locale(value), "#{value.inspect} was not restricted"
          end
        end

        test 'the resolved locale is always one of the configured locales' do
          ['de', 'en', 'zz', 'garbage', '', nil].each do |value|
            assert_includes I18n.available_locales, resolved_locale(value), "#{value.inspect} resolved outside available_locales"
          end
        end
      end
    end
  end
end
