# frozen_string_literal: true

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

    let(:template_class_hash) do
      {
        'label' => 'Geplante Publikation',
        'type' => 'embedded',
        'linked_table' => 'creative_works',
        'template_name' => 'Publikations-Plan',
        'validations' => {
          'classifications' => 'no_conflicts'
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

    after do
      DataCycleCore::CreativeWork.find_by(id: '00000000-0000-0000-0000-000000000000')&.destroy
      DataCycleCore::CreativeWork.find_by(id: '00000000-0000-0000-0000-000000000001')&.destroy
    end

    it 'successfully validates embedded Bild' do
      uuid = bild1.id
      validator = subject.new([{ 'id' => uuid }], template_hash, 'Bilder')
      assert_equal(0, validator.error[:error].size)
    end

    it 'successfully validates more than one embedded item' do
      new_template_hash = template_hash.deep_dup.except('validations')
      uuid = bild1.id
      uuid2 = bild2.id
      data_cases = [
        [{ 'id' => uuid }],
        [{ 'id' => uuid }, { 'id' => uuid2 }]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, new_template_hash)
        assert_equal(0, validator.error[:error].size)
      end
    end

    it 'rejects data in the following formats' do
      new_template_hash = template_hash.deep_dup.except('validations')
      uuid = bild1.id
      uuid2 = bild2.id
      data_cases = [
        uuid,
        [uuid],
        [uuid, uuid2],
        [{ 'id' => uuid }, uuid2]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, new_template_hash)
        assert_equal(1, validator.error[:error].size)
      end
    end

    it 'validates properly classification_conflicts for a single classification' do
      old_class = DataCycleCore.features[:publication_schedule][:classification_keys]
      DataCycleCore.features[:publication_schedule][:classification_keys] = ['output_channel']

      output_channel1 = DataCycleCore::Classification.where(name: 'Web').first.id
      output_channel2 = DataCycleCore::Classification.where(name: 'Social Media').first.id

      data_hash1 = [
        { 'output_channel' => [output_channel1] },
        { 'output_channel' => [output_channel2] }
      ]
      validator = subject.new(data_hash1, template_class_hash)
      assert_equal(0, validator.error[:error].size)

      data_hash2 = [
        { 'output_channel' => [output_channel1] },
        { 'output_channel' => [output_channel1, output_channel2] }
      ]
      validator = subject.new(data_hash2, template_class_hash)
      assert_equal(1, validator.error[:error].size)

      DataCycleCore.features[:publication_schedule][:classification_keys] = old_class
    end

    it 'validates properly classification_conflicts for multiple classifications' do
      old_class = DataCycleCore.features[:publication_schedule][:classification_keys]
      DataCycleCore.features[:publication_schedule][:classification_keys] = ['output_channel', 'markets']

      market1 = DataCycleCore::Classification.where(name: 'Australien').first.id
      market2 = DataCycleCore::Classification.where(name: 'Belgien').first.id

      output_channel1 = DataCycleCore::Classification.where(name: 'Web').first.id
      output_channel2 = DataCycleCore::Classification.where(name: 'Social Media').first.id

      data_hash1 = [
        { 'markets' => [market2], 'output_channel' => [output_channel1] },
        { 'markets' => [market1], 'output_channel' => [output_channel2] }
      ]
      validator = subject.new(data_hash1, template_class_hash)
      assert_equal(0, validator.error[:error].size)

      data_hash2 = [
        { 'markets' => [market1, market2], 'output_channel' => [output_channel1] },
        { 'markets' => [market2], 'output_channel' => [output_channel2] }
      ]
      validator = subject.new(data_hash2, template_class_hash)
      assert_equal(0, validator.error[:error].size)

      data_hash3 = [
        { 'markets' => [market1, market2], 'output_channel' => [output_channel1] },
        { 'markets' => [market2], 'output_channel' => [output_channel1, output_channel2] }
      ]
      validator = subject.new(data_hash3, template_class_hash)
      assert_equal(1, validator.error[:error].size)

      DataCycleCore.features[:publication_schedule][:classification_keys] = old_class
    end
  end
end