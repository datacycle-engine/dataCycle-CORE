# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::OpenStructHash do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::OpenStructHash
  end

  describe 'validate data' do
    it 'handles data like a hash' do
      data = subject.new('test_key' => 'test_value')

      assert_equal({ 'test_key' => 'test_value' }, data.to_h)
      assert_equal('test_value', data['test_key'])
    end

    it 'behaves correctly if empty' do
      data = subject.new

      assert_empty(data.to_h)
    end
  end
end
