# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmailHelperTest < ActionView::TestCase
    include DataCycleCore::EmailHelper

    test 'user_additional_tile_attribute_value passes plain values through' do
      assert_equal 'John', user_additional_tile_attribute_value('name', 'John', :de)
    end

    test 'user_additional_tile_attribute_value returns a blank time value unchanged' do
      assert_nil user_additional_tile_attribute_value('created_at', nil, :de)
    end

    test 'user_additional_tile_attribute_value localizes time values' do
      assert_equal '15.01.2024 09:30', user_additional_tile_attribute_value('last_sign_in', Time.zone.local(2024, 1, 15, 9, 30), :de)
    end

    test 'first_available_i18n_t resolves the first existing namespaced translation' do
      result = first_available_i18n_t('actions.?', ['finalize'])

      assert_equal 'Bearbeitung final abschließen', result
      assert_predicate result, :html_safe?
    end

    test 'first_available_i18n_t resolves the placeholder inside a scope option' do
      assert_equal 'Bearbeitung final abschließen', first_available_i18n_t('?', ['finalize'], scope: 'actions')
    end
  end
end
