# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Differs::Embedded do
  subject do
    DataCycleCore::MasterData::Differs::Embedded
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Inhaltstyp',
        'type' => 'embedded',
        'template_name' => 'Bild'
      }
    end

    it 'successfully recognizes these cases as equivalent' do
      uuid = DataCycleCore::Thing.find_by(template_name: 'Bild').id
      data_cases = [
        [nil, nil],
        [uuid, uuid],
        [uuid, [uuid]],
        [[uuid], uuid],
        [[uuid], [uuid]],
        [[{ 'id' => uuid }], [uuid]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_nil(differ.diff_hash)
      end
    end

    it 'successfully recognizes order changes' do
      uuid = DataCycleCore::Thing.find_by(template_name: 'Bild').id
      uuid2 = DataCycleCore::Thing.find_by(template_name: 'Video').id
      data_cases = [
        [[{ 'id' => uuid }, { 'id' => uuid2 }], [uuid2, uuid], [['>', uuid, 0, 1], ['<', uuid2, 1, 0]]],
        [[{ 'id' => uuid2 }, { 'id' => uuid }], [uuid, uuid2], [['>', uuid2, 0, 1], ['<', uuid, 1, 0]]]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template_hash)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end

    it 'successfully recognizes changed items' do
      template = {
        'label' => 'Bilder',
        'type' => 'embedded',
        'template_name' => 'Bild'
      }
      uuid = '00000000-0000-0000-0000-000000000000'
      uuid2 = '11111111-1111-1111-1111-111111111111'
      data_cases = [
        [
          [{ 'id' => uuid, 'name' => 'Bild initially' }],
          { 'id' => uuid, 'name' => 'Bild changed' },
          [['~', ['00000000-0000-0000-0000-000000000000']]]
        ],
        [
          [{ 'id' => uuid, 'name' => 'Bild initially' }],
          [{ 'id' => uuid, 'name' => 'Bild changed' }],
          [['~', ['00000000-0000-0000-0000-000000000000']]]
        ],
        [
          [{ 'id' => uuid, 'name' => 'Bild initially' }, { 'id' => uuid2, 'name' => 'Bild 2' }],
          { 'id' => uuid, 'name' => 'Bild changed' },
          [['-', ['11111111-1111-1111-1111-111111111111']], ['~', ['00000000-0000-0000-0000-000000000000']]]
        ]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end

    it 'successfully handles relation objects' do
      uuid = DataCycleCore::Thing.find_by(template_name: 'Bild').id
      uuid2 = DataCycleCore::Thing.find_by(template_name: 'PlaceOverlay').id
      uuid3 = DataCycleCore::Thing.find_by(template_name: 'Video').id
      uuids = DataCycleCore::Thing.where(template_name: ['Bild', 'Video', 'PlaceOverlay']).order(template_name: :asc)
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
