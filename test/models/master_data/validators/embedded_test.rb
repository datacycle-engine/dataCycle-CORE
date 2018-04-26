require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Embedded do
  subject do
    DataCycleCore::MasterData::Validators::Embedded
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Bilder',
        'type' => 'embedded',
        'linked_table' => 'creative_works',
        'template_name' => 'Bild',
        'validations' => {
          'max' => 1
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    let(:bild1) do
      DataCycleCore::CreativeWork.find_or_create_by!(id: '00000000-0000-0000-0000-000000000000') do |item|
        item.headline = 'Bild1'
      end
    end

    let(:bild2) do
      DataCycleCore::CreativeWork.find_or_create_by!(id: '00000000-0000-0000-0000-000000000001') do |item|
        item.headline = 'Bild2'
      end
    end

    it 'successfully validates embedded Bild' do
      uuid = bild1.id
      validator = subject.new([uuid], template_hash, 'Bilder')
      assert_equal(no_error_hash, validator.error)
    end

    it 'successfully validates more than one embedded item' do
      new_template_hash = template_hash.deep_dup.except('validations')
      uuid = bild1.id
      uuid2 = bild2.id
      data_cases = [
        uuid,
        [uuid],
        [uuid, uuid2],
        [{ 'id' => uuid }],
        [{ 'id' => uuid }, { 'id' => uuid2 }],
        [{ 'id' => uuid }, uuid2]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, new_template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end
