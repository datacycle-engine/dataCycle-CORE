# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Utility::Compute::Classification do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::Utility::Compute::Classification
  end

  describe 'testing classification method: keywords' do
    it 'one attribute given' do
      classifications = DataCycleCore::Classification.limit(2)
      assert_equal(classifications.map(&:name).join(','), subject.keywords(computed_parameters: { key: classifications.pluck(:id) }))
    end

    it 'more than one attribute given' do
      classifications = DataCycleCore::Classification.limit(4)
      computed_first = [classifications.first] + [classifications.second]
      computed_second = [classifications.third]
      computed_third = [classifications.fourth]
      expected_string = [computed_first.map(&:name), computed_second.map(&:name), computed_third.map(&:name)].flatten.join(',')
      assert_equal(expected_string, subject.keywords(computed_parameters: { key1: computed_first.map(&:id), key2: computed_second.map(&:id), key3: computed_third.map(&:id) }))
    end

    it 'no attribute given' do
      assert_nil(subject.keywords(computed_parameters: { key: nil }))
    end

    it 'empty attribute given' do
      assert_nil(subject.keywords(computed_parameters: { key: [] }))
    end
  end
end
