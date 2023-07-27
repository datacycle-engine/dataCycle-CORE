# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Date do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Date
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'date',
        'storage_location' => 'translated_value'
      }
    end

    it 'properly diffs equal dates' do
      a = '2018-01-01'.to_date
      [
        [a, a],
        [a.to_s, a],
        [a.inspect, a],
        [a.send(:to_date), a],
        [a.to_date, a]
      ].each do |item|
        assert_nil(subject.new(item[0], item[1]).diff_hash)
      end
    end

    it 'recognizes a deleted value' do
      a = '2018-01-01'.to_date
      [a, a.to_s, a.inspect, a.send(:to_date), a.to_date].each do |item|
        assert_equal(['-', a], subject.new(item, nil).diff_hash)
      end
    end

    it 'recognizes an inserted value' do
      a = '2018-01-01'.to_date
      [a, a.to_s, a.inspect, a.send(:to_date), a.to_date].each do |item|
        assert_equal(['+', a], subject.new(nil, item, template_hash).diff_hash)
        assert_equal(['+', a], subject.new(nil, item).diff_hash)
      end
    end
  end
end
