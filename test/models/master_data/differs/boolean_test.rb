# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Boolean do
  subject do
    DataCycleCore::MasterData::Differs::Boolean
  end

  describe 'diff data' do
    let(:template_hash) do
      {
        'label' => 'Test',
        'type' => 'boolean',
        'storage_location' => 'translated_value'
      }
    end

    it 'properly diffs equal bools' do
      [
        [true, true],
        [true, 'true'],
        ['true', true],
        ['true', 'true'],
        [false, false],
        [false, 'false'],
        ['false', false],
        ['false', 'false']
      ].each do |item|
        assert_nil(subject.new(item[0], item[1], template_hash).diff_hash)
        assert_nil(subject.new(item[0], item[1]).diff_hash)
      end
    end

    it 'recognizes a deleted value' do
      [true, false, 'true', 'false'].each do |item|
        bool_item = DataCycleCore::MasterData::DataConverter.string_to_boolean(item)
        assert_equal(['-', bool_item], subject.new(item, nil, template_hash).diff_hash)
        assert_equal(['-', bool_item], subject.new(item, nil).diff_hash)
      end
    end

    it 'recognizes an inserted value' do
      [true, false, 'true', 'false'].each do |item|
        bool_item = DataCycleCore::MasterData::DataConverter.string_to_boolean(item)
        assert_equal(['+', bool_item], subject.new(nil, item, template_hash).diff_hash)
        assert_equal(['+', bool_item], subject.new(nil, item).diff_hash)
      end
    end
  end
end
