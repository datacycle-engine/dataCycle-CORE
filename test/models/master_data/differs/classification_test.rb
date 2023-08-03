# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Classification do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Classification
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Inhaltstyp',
        'type' => 'classification',
        'tree_label' => 'Inhaltstypen'
      }
    end

    it 'successfully recognizes these cases as equivalent' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      uuid2 = DataCycleCore::Classification.find_by(name: 'Video').id
      data_cases = [
        [nil, nil],
        [uuid, uuid],
        [uuid, [uuid]],
        [[uuid], uuid],
        [[uuid], [uuid]],
        [[uuid, uuid2], [uuid, uuid2]],
        [[uuid, uuid2], [uuid2, uuid]],
        [[uuid2, uuid], [uuid, uuid2]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_nil(differ.diff_hash)
      end
    end

    it 'successfully recognizes additions' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      uuid2 = DataCycleCore::Classification.find_by(name: 'Video').id
      data_cases = [
        # a, b, a diff b
        [nil, uuid, [uuid]],
        [nil, [uuid], [uuid]],
        [uuid, [uuid, uuid2], [uuid2]],
        [uuid, [uuid2, uuid], [uuid2]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal([['+', case_item[2]]], differ.diff_hash)
      end
    end

    it 'successfully recognizes deletions' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      uuid2 = DataCycleCore::Classification.find_by(name: 'Video').id
      data_cases = [
        # a, b, a diff b
        [uuid, nil, [uuid]],
        [[uuid], nil, [uuid]],
        [[uuid, uuid2], uuid, [uuid2]],
        [[uuid2, uuid], uuid, [uuid2]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal([['-', case_item[2]]], differ.diff_hash)
      end
    end

    it 'successfully does additions and deletions' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      uuid2 = DataCycleCore::Classification.find_by(name: 'Video').id
      uuid3 = DataCycleCore::Classification.find_by(name: 'Audio').id
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
      uuid = DataCycleCore::Classification.find_by(name: 'Audio').id
      uuid2 = DataCycleCore::Classification.find_by(name: 'Bild').id
      uuid3 = DataCycleCore::Classification.find_by(name: 'Video').id
      uuids = DataCycleCore::Classification.where(name: ['Audio', 'Bild', 'Video']).order(name: :asc)
      data_cases = [
        [[uuid, uuid2, uuid3], uuids],
        [[uuid3, uuid, uuid2], uuids]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_nil(differ.diff_hash)
      end
    end
  end
end
