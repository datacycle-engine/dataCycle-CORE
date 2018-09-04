# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Datetime do
  subject do
    DataCycleCore::MasterData::Differs::Datetime
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'datetime',
        'storage_location' => 'translated_value'
      }
    end

    it 'properly diffs equal datetimes' do
      a = '2018-01-01'.in_time_zone
      [
        [a, a],
        [a.to_s, a],
        [a.inspect, a],
        [a.send(:to_time), a],
        [a.to_datetime, a]
      ].each do |item|
        assert_nil(subject.new(item[0], item[1]).diff_hash)
      end
    end

    it 'recognizes a deleted value' do
      a = '2018-01-01'.in_time_zone
      [a, a.to_s, a.inspect, a.send(:to_time), a.to_datetime].each do |item|
        assert_equal(['-', a], subject.new(item, nil).diff_hash)
      end
    end

    it 'recognizes an inserted value' do
      a = '2018-01-01'.in_time_zone
      [a, a.to_s, a.inspect, a.send(:to_time), a.to_datetime].each do |item|
        assert_equal(['+', a], subject.new(nil, item, template_hash).diff_hash)
        assert_equal(['+', a], subject.new(nil, item).diff_hash)
      end
    end
  end
end
