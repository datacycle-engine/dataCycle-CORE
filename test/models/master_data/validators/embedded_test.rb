# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Embedded do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Embedded
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Bilder',
        'type' => 'embedded',
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
      DataCycleCore::Thing.find_or_create_by!(id: '00000000-0000-0000-0000-000000000000', template_name: 'Bild') do |item|
        item.name = 'Bild1'
      end
    end

    let(:bild2) do
      DataCycleCore::Thing.find_or_create_by!(id: '00000000-0000-0000-0000-000000000001', template_name: 'Bild') do |item|
        item.name = 'Bild2'
      end
    end

    after do
      DataCycleCore::Thing.find_by(id: '00000000-0000-0000-0000-000000000000')&.destroy
      DataCycleCore::Thing.find_by(id: '00000000-0000-0000-0000-000000000001')&.destroy
    end

    it 'successfully validates embedded Bild' do
      uuid = bild1.id
      validator = subject.new([{ 'id' => uuid }], template_hash, 'Bilder')
      assert_equal(0, validator.error[:error].size)
    end

    # it 'produces a warning if no data are given' do
    #   validator = subject.new(nil, template_hash.deep_dup)
    #   assert_equal(0, validator.error[:error].size)
    #   assert_equal(1, validator.error[:warning].size)
    # end

    it 'produces no error if a wrong validations keyword is given' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['validations'] = { 'maxi' => 2 }
      item_case = [{ 'id' => SecureRandom.uuid }]
      validator = subject.new(item_case, new_template_hash)
      assert_equal(0, validator.error[:error].size)
    end

    it 'produces an error if a wrong template_name is given' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['template_name'] = 'maxi'
      item_case = [{ 'id' => SecureRandom.uuid }]
      validator = subject.new(item_case, new_template_hash)
      assert_equal(1, validator.error[:error].size)
    end

    it 'successfully validates more than one embedded item' do
      new_template_hash = template_hash.deep_dup.except('validations')
      uuid = bild1.id
      uuid2 = bild2.id
      data_cases = [
        { 'id' => uuid },
        [{ 'id' => uuid }],
        [{ 'id' => uuid }, { 'id' => uuid2 }]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, new_template_hash)
        assert_equal(0, validator.error[:error].size)
      end
    end

    it 'produces an error if max is exceeded' do
      new_template_hash = template_hash.deep_dup
      uuid = bild1.id
      uuid2 = bild2.id
      item_case = [{ 'id' => uuid }, { 'id' => uuid2 }]
      validator = subject.new(item_case, new_template_hash)
      assert_equal(1, validator.error[:error].size)
    end

    it 'produces an error if min is not reached' do
      new_template_hash = template_hash.deep_dup
      new_template_hash['validations'] = { 'min' => 2 }
      uuid = bild1.id
      item_case = [{ 'id' => uuid }]
      validator = subject.new(item_case, new_template_hash)
      assert_equal(1, validator.error[:error].size)
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

      market1 = DataCycleCore::Classification.where(name: 'Markt 1').first.id
      market2 = DataCycleCore::Classification.where(name: 'Markt 2').first.id

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
