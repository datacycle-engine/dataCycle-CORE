# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Asset do
  subject do
    DataCycleCore::MasterData::Validators::Asset
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Local-Asset',
        'type' => 'asset',
        'asset_type' => 'asset'
      }
    end

    let(:template_hash_length) do
      {
        'label' => 'Local-Asset',
        'type' => 'asset',
        'asset_type' => 'asset',
        'validations' => {
          'min' => 1,
          'max' => 2
        }
      }
    end

    let(:template_hash_length_w_error) do
      {
        'label' => 'Local-Asset',
        'type' => 'asset',
        'asset_type' => 'asset',
        'validations' => {
          'unknown' => 1,
          'max' => 2
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    let(:asset1) do
      DataCycleCore::Asset.find_or_create_by!(id: '00000000-0000-0000-0000-000000000000')
    end

    let(:image1) do
      DataCycleCore::Image.find_or_create_by!(id: '00000000-0000-0000-0000-000000000001')
    end

    let(:video1) do
      DataCycleCore::Video.find_or_create_by!(id: '00000000-0000-0000-0000-000000000002')
    end

    after do
      DataCycleCore::Asset.find_by(id: '00000000-0000-0000-0000-000000000000')&.destroy
      DataCycleCore::Image.find_by(id: '00000000-0000-0000-0000-000000000001')&.destroy
      DataCycleCore::Video.find_by(id: '00000000-0000-0000-0000-000000000002')&.destroy
    end

    it 'properly validates a AssetObject' do
      assert_equal(no_error_hash, subject.new([asset1.id], template_hash).error)
    end

    it 'properly validates a ImageObject' do
      assert_equal(no_error_hash, subject.new([image1.id], template_hash).error)
    end

    it 'properly validates a VideoObject' do
      assert_equal(no_error_hash, subject.new([video1.id], template_hash).error)
    end

    it 'produces a warning if no uuid given' do
      data_cases = [nil, '', ['']]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(1, validator.error[:warning].size)
      end
    end

    it 'successfully validates in these cases' do
      data_cases = [
        asset1.id,
        image1.id,
        video1.id,
        [asset1.id, image1.id, video1.id]
      ]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash)
        assert_equal(no_error_hash, validator.error)
      end
    end

    it 'successfully validates with min, max given' do
      uuids = [asset1.id, image1.id]
      validator = subject.new(uuids, template_hash_length)
      assert_equal(no_error_hash, validator.error)
    end

    it 'properly errors out when length restrictions are not met' do
      data_cases = [
        [],
        [asset1.id, image1.id, video1.id]
      ]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash_length)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'add warnings for invalid value' do
      uuids = [1, asset1.id]
      validator = subject.new(uuids, template_hash_length)
      assert_equal(0, validator.error[:error].size)
      assert_equal(1, validator.error[:warning].size)
    end

    it 'add warnings for invalid validation key' do
      uuids = asset1.id
      validator = subject.new(uuids, template_hash_length_w_error)
      assert_equal(0, validator.error[:error].size)
      assert_equal(1, validator.error[:warning].size)
    end
  end
end
