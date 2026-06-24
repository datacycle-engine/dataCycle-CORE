# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class NormalizeServiceTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def includer
      Class.new { include DataCycleCore::NormalizeService }.new
    end

    test 'normalize_data_hash rejects blank values' do
      result = includer.normalize_data_hash({ 'name' => 'keep', 'empty' => '' })

      assert_equal 'keep', result['name']
      assert_not result.key?('empty')
    end

    test 'normalize_parameters converts integer-keyed hashes to arrays' do
      params = { 'items' => { '0' => { 'name' => 'x' }, '1' => { 'name' => 'y' } } }

      DataCycleCore::NormalizeService.normalize_parameters(params)

      assert_kind_of Array, params['items']
      assert_equal 2, params['items'].size
    end

    test 'normalize_encoding sanitizes the string encoding' do
      assert_equal 'abc', DataCycleCore::NormalizeService.normalize_encoding('abc')
    end
  end
end
