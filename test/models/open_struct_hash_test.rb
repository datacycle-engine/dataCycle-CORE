# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::OpenStructHash do
  subject do
    DataCycleCore::OpenStructHash
  end

  describe 'validate data' do
    it 'handles data like a hash' do
      data = subject.new('test_key' => 'test_value')
      assert_equal(data.to_h, { 'test_key' => 'test_value' })
      assert_equal(data['test_key'], 'test_value')
    end

    it 'behaves correctly if empty' do
      data = subject.new
      assert_equal(data.to_h, {})
    end
  end
end
