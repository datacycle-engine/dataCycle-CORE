# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::UuidSet do
  subject do
    DataCycleCore::MasterData::Differs::UuidSet
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Inhaltstyp',
        'type' => 'linked',
        'template_name' => 'Bild'
      }
    end

    it 'successfully recognizes these cases as equivalent' do
      uuid = SecureRandom.uuid
      data_cases = [
        [nil, nil],
        [uuid, uuid],
        [uuid, [uuid]],
        [[uuid], uuid],
        [[uuid], [uuid]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], nil)
        assert_nil(differ.diff_hash)
      end
    end

    it 'successfully recognizes additions' do
      uuid = SecureRandom.uuid
      uuid2 = SecureRandom.uuid
      data_cases = [
        # a, b, a diff b
        [nil, uuid, [['+', [uuid]]]],
        [nil, [uuid], [['+', [uuid]]]],
        [uuid, [uuid, uuid2], [['+', [uuid2]]]],
        [uuid, [uuid2, uuid], [['+', [uuid2]]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end

    it 'successfully recognizes deletions' do
      uuid = SecureRandom.uuid
      uuid2 = SecureRandom.uuid
      data_cases = [
        # a, b, a diff b
        [uuid, nil, [['-', [uuid]]]],
        [[uuid], nil, [['-', [uuid]]]],
        [[uuid, uuid2], uuid, [['-', [uuid2]]]],
        [[uuid2, uuid], uuid, [['-', [uuid2]]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end

    it 'successfully does additions and deletions' do
      uuid = SecureRandom.uuid
      uuid2 = SecureRandom.uuid
      uuid3 = SecureRandom.uuid
      data_cases = [
        # a, b, a diff b
        [uuid, uuid2, [['+', [uuid2]], ['-', [uuid]]]],
        [uuid2, uuid, [['+', [uuid]], ['-', [uuid2]]]],
        [[uuid], [uuid2, uuid3], [['+', [uuid2, uuid3].sort], ['-', [uuid]]]],
        [[uuid, uuid2], [uuid3], [['+', [uuid3]], ['-', [uuid, uuid2].sort]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end
  end
end
