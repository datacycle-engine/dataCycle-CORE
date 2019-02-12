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
end
