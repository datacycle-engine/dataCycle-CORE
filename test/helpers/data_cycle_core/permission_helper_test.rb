# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class PermissionHelperTest < ActionView::TestCase
    include DataCycleCore::PermissionHelper

    test 'resolve_attribute_translation returns plain restrictions unchanged' do
      assert_equal 'read', resolve_attribute_translation('read', {})
    end

    test 'resolve_attribute_translation joins nested array restrictions' do
      assert_equal 'read, write', resolve_attribute_translation(['read', 'write'], {})
    end

    test 'resolve_attribute_translation recurses into nested arrays' do
      assert_equal 'a, b, c', resolve_attribute_translation(['a', ['b', 'c']], {})
    end
  end
end
