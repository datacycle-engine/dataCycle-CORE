# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserHelperTest < ActionView::TestCase
    include DataCycleCore::UserHelper
    include DataCycleCore::UiLocaleHelper

    test 'user_additional_tile_attribute_value passes plain values through' do
      assert_equal 'John', user_additional_tile_attribute_value('name', 'John')
    end

    test 'user_additional_tile_attribute_value returns a blank time value unchanged' do
      assert_nil user_additional_tile_attribute_value('created_at', nil)
    end

    test 'user_additional_tile_attribute_value localizes time values' do
      assert_equal '15.01.2024 09:30', user_additional_tile_attribute_value('last_sign_in', Time.zone.local(2024, 1, 15, 9, 30))
    end
  end
end
