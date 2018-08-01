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
        'linked_table' => 'creative_works',
        'template_name' => 'Bild'
      }
    end

    # it 'successfully recognizes these cases as equivalent' do
    #   uuid = DataCycleCore::CreativeWork.find_by(template_name: 'Bild').id
    #   data_cases = [
    #     [nil, nil],
    #     [uuid, uuid],
    #     [uuid, [uuid]],
    #     [[uuid], uuid],
    #     [[uuid], [uuid]],
    #     [[{ 'id' => uuid }], [uuid]]
    #   ]
    #   data_cases.each do |case_item|
    #     differ = subject.new(case_item[0], case_item[1], template_hash)
    #     assert_nil(differ.diff_hash)
    #   end
    # end
    #
    # it 'successfully recognizes order changes' do
    #   uuid = DataCycleCore::CreativeWork.find_by(template_name: 'Bild').id
    #   uuid2 = DataCycleCore::CreativeWork.find_by(template_name: 'Video').id
    #   data_cases = [
    #     [[{ 'id' => uuid }, { 'id' => uuid2 }], [uuid2, uuid], [['>', uuid, 0, 1], ['<', uuid2, 1, 0]]],
    #     [[{ 'id' => uuid2 }, { 'id' => uuid }], [uuid, uuid2], [['>', uuid2, 0, 1], ['<', uuid, 1, 0]]]
    #   ]
    #   data_cases.each do |case_item|
    #     differ = subject.new(case_item[0], case_item[1], template_hash)
    #     assert_equal(case_item[2], differ.diff_hash)
    #   end
    # end

    it 'successfully recognizes changed items' do
      template = {
        'label' => 'Bilder',
        'type' => 'embedded',
        'linked_table' => 'creative_works',
        'template_name' =>  'Bild'
      }
      uuid = '00000000-0000-0000-0000-000000000000'
      uuid2 = '11111111-1111-1111-1111-111111111111'
      data_cases = [
        [
          [{ 'id' => uuid, 'headline' => 'Bild initially' }],
          { 'id' => uuid, 'headline' => 'Bild changed' },
          [['~', ['00000000-0000-0000-0000-000000000000']]]
        ],
        [
          [{ 'id' => uuid, 'headline' => 'Bild initially' }],
          [{ 'id' => uuid, 'headline' => 'Bild changed' }],
          [['~', ['00000000-0000-0000-0000-000000000000']]]
        ],
        [
          [{ 'id' => uuid, 'headline' => 'Bild initially' }, { 'id' => uuid2, 'headline' => 'Bild 2' }],
          { 'id' => uuid, 'headline' => 'Bild changed' },
          [['-', ['11111111-1111-1111-1111-111111111111']], ['~', ['00000000-0000-0000-0000-000000000000']]]
        ]
      ]
      data_cases.each do |case_item|
        differ = subject.new(case_item[0], case_item[1], template)
        assert_equal(case_item[2], differ.diff_hash)
      end
    end
  end
end
