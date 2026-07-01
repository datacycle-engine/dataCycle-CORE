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

  test 'uuid? matches the whole string and rejects multiline injection payloads' do
    assert_predicate('f47ac10b-58cc-4372-a567-0e02b2c3d479', :uuid?)
    assert_not('not-a-uuid'.uuid?)
    assert_not("f47ac10b-58cc-4372-a567-0e02b2c3d479\n'); DROP TABLE things; --".uuid?, 'a value whose first line is a valid uuid must NOT be accepted as a uuid (^...$ line anchors would otherwise let injection payloads pass validation)')
  end
end
