# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Utility::Compute::Classification do
  subject do
    DataCycleCore::Utility::Compute::Classification
  end

  describe 'testing classification method: keywords' do
    it 'one attribute given' do
      classifications = DataCycleCore::Classification.all.limit(2)
      assert_equal(classifications.map(&:name).join(','), subject.keywords({ computed_parameters: classifications.map(&:id) }))
    end
    it 'more than one attribute given' do
      classifications = DataCycleCore::Classification.all.limit(4)
      computed_first = [classifications.first] + [classifications.second]
      computed_second = [classifications.third]
      computed_third = [classifications.fourth]
      expected_string = [computed_first.map(&:name), computed_second.map(&:name), computed_third.map(&:name)].flatten.join(',')
      assert_equal(expected_string, subject.keywords({ computed_parameters: [computed_first.map(&:id), computed_second.map(&:id), computed_third.map(&:id)] }))
    end
    it 'no attribute given' do
      assert_nil(subject.keywords({ computed_parameters: nil }))
    end
    it 'empty attribute given' do
      assert_nil(subject.keywords({ computed_parameters: [] }))
    end
  end
end