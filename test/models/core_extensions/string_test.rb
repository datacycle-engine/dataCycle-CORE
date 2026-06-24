# frozen_string_literal: true

require 'test_helper'

class StringTest < ActiveSupport::TestCase
  test 'test additional string functionality' do
    assert_nil(''.attribute_name_from_key)
    assert_equal('a', 'a'.attribute_name_from_key)
    assert_equal('third', 'third'.attribute_name_from_key)
    assert_equal('third', 'first[third]'.attribute_name_from_key)
    assert_equal('third', 'first[second][third]'.attribute_name_from_key)
  end

  test 'test safe_squish' do
    assert_equal("\u00A0", "\u00A0".safe_squish)
    assert_equal("\u00A0", "\u00A0\u00A0\u00A0".safe_squish)
    assert_equal("\u00A0", "\u00A0 \u00A0".safe_squish)
    assert_equal("test\u00A0test2", "test\u00A0 \u00A0test2".safe_squish)
    assert_equal('test test2', 'test  test2'.safe_squish)
  end
end
