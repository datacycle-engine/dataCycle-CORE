# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Asset do
  subject do
    DataCycleCore::MasterData::Validators::Asset
  end

  def upload_file(path_to_file)
    File.join(DataCycleCore::TestPreparations::ASSETS_PATH, path_to_file)
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Local-Asset',
        'type' => 'asset',
        'asset_type' => 'text_file'
      }
    end
    let(:template_image_hash) do
      {
        'label' => 'Local-Asset',
        'type' => 'asset',
        'asset_type' => 'image'
      }
    end

    let(:template_hash_length_w_error) do
      {
        'label' => 'Local-Asset',
        'type' => 'asset',
        'asset_type' => 'text_file',
        'validations' => {
          'required' => true,
          'invalid_validation' => 1
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    let(:asset1) do
      asset = DataCycleCore::TextFile.new(
        id: '00000000-0000-0000-0000-000000000000',
        file: File.open(upload_file('pdf/test.pdf'))
      )
      asset.save
      asset
    end

    let(:image1) do
      image = DataCycleCore::Image.new(
        id: '00000000-0000-0000-0000-000000000001',
        file: File.open(upload_file('images/test_rgb.jpg'))
      )
      image.save
      image
    end

    after do
      DataCycleCore::TextFile.find_by(id: '00000000-0000-0000-0000-000000000000')&.destroy
      DataCycleCore::Image.find_by(id: '00000000-0000-0000-0000-000000000001')&.destroy
    end

    it 'properly validates a AssetObject' do
      assert_equal(no_error_hash, subject.new([asset1.id], template_hash).error)
    end

    it 'properly validates a ImageObject' do
      assert_equal(no_error_hash, subject.new([image1.id], template_image_hash).error)
    end

    it 'produces an error if no uuid given' do
      data_cases = [nil, '', ['']]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash_length_w_error) # byebug
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'produces an error if the data given is not a valid uuid or DataCyclCore::Asset Object' do
      data_cases = ['00000000-xxxx-0000-0000-000000000001', ['test']]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'successfully validates in these cases' do
      data_cases = [
        asset1.id,
        asset1
      ]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash)
        assert_equal(no_error_hash, validator.error)
      end
    end

    it 'no warnings for invalid validation key' do
      uuids = asset1.id
      validator = subject.new(uuids, template_hash_length_w_error)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'add warnings for invalid asset_type' do
      uuids = image1.id
      validator = subject.new(uuids, template_hash)
      assert_equal(0, validator.error[:error].size)
      assert_equal(1, validator.error[:warning].size)
    end
  end
end
