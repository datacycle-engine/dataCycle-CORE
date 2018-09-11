# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Linked do
  subject do
    DataCycleCore::MasterData::Differs::Linked
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Inhaltstyp',
        'type' => 'linked',
        'linked_table' => 'creative_works'
      }
    end

    it 'successfully recognizes order changes' do
      uuid = DataCycleCore::CreativeWork.find_by(template_name: 'Bild').id
      uuid2 = DataCycleCore::CreativeWork.find_by(template_name: 'Video').id
      data_cases = [
        [[uuid, uuid2], [uuid2, uuid], [['>', uuid, 0, 1], ['<', uuid2, 1, 0]]],
        [[uuid2, uuid], [uuid, uuid2], [['>', uuid2, 0, 1], ['<', uuid, 1, 0]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end

    it 'successfully recognizes additions' do
      uuid = DataCycleCore::CreativeWork.find_by(template_name: 'Bild').id
      uuid2 = DataCycleCore::CreativeWork.find_by(template_name: 'Video').id
      data_cases = [
        # a, b, a diff b
        [nil, uuid, [['+', [uuid]]]],
        [nil, [uuid], [['+', [uuid]]]],
        [uuid, [uuid, uuid2], [['+', [uuid2]]]],
        [uuid, [uuid2, uuid], [['+', [uuid2]], ['>', uuid, 0, 1]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end

    it 'successfully recognizes deletions' do
      uuid = DataCycleCore::CreativeWork.find_by(template_name: 'Bild').id
      uuid2 = DataCycleCore::CreativeWork.find_by(template_name: 'Video').id
      data_cases = [
        # a, b, a diff b
        [uuid, nil, [['-', [uuid]]]],
        [[uuid], nil, [['-', [uuid]]]],
        [[uuid, uuid2], uuid, [['-', [uuid2]]]],
        [[uuid2, uuid], uuid, [['-', [uuid2]], ['<', uuid, 1, 0]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end

    it 'successfully does additions and deletions' do
      uuid = DataCycleCore::CreativeWork.find_by(template_name: 'Bild').id
      uuid2 = DataCycleCore::CreativeWork.find_by(template_name: 'Video').id
      uuid3 = DataCycleCore::CreativeWork.find_by(template_name: 'Zitat').id
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

    it 'successfully handles relation objects' do
      uuid = DataCycleCore::CreativeWork.find_by(template_name: 'Bild').id
      uuid2 = DataCycleCore::CreativeWork.find_by(template_name: 'Video').id
      uuid3 = DataCycleCore::CreativeWork.find_by(template_name: 'Zitat').id
      uuids = DataCycleCore::CreativeWork.where(template_name: ['Bild', 'Video', 'Zitat']).order(template_name: :asc)
      data_cases = [
        [[uuid2, uuid, uuid3], uuids, [['>', uuid2, 0, 1], ['<', uuid, 1, 0]]],
        [[uuid3, uuid2, uuid], uuids, [['>', uuid3, 0, 2], ['<', uuid, 2, 0]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end
  end
end
