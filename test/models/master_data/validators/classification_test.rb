# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Validators::Classification do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Validators::Classification
  end

  describe 'validate data' do
    let(:template_hash) do
      {
        'label' => 'Inhaltstyp',
        'type' => 'classification',
        'tree_label' => 'Inhaltstypen',
        'default_value' => 'Bild'
      }
    end

    let(:template_hash_length) do
      {
        'label' => 'Inhaltstyp',
        'type' => 'classification',
        'tree_label' => 'Inhaltstypen',
        'default_value' => 'Bild',
        'validations' => {
          'min' => 2,
          'max' => 3
        }
      }
    end

    let(:template_hash_required) do
      {
        'label' => 'Inhaltstyp',
        'type' => 'classification',
        'tree_label' => 'Inhaltstypen',
        'default_value' => 'Bild',
        'validations' => {
          'required' => true
        }
      }
    end

    let(:template_hash_universal_classification) do
      {
        'label' => 'Klassifizierungen',
        'type' => 'classification',
        'universal' => true
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    it 'properly validates a DateObject' do
      classification = DataCycleCore::Classification.find_by(name: 'Bild')
      assert_equal(no_error_hash, subject.new([classification.id], template_hash).error)
    end

    it 'successfully validates in these cases' do
      data_cases = [
        DataCycleCore::Classification.find_by(name: 'Bild').id,
        [DataCycleCore::Classification.find_by(name: 'Bild').id],
        [DataCycleCore::Classification.find_by(name: 'Bild').id, DataCycleCore::Classification.find_by(name: 'Video').id]
      ]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash)
        assert_equal(no_error_hash, validator.error)
      end
    end

    it 'successfully validates with required given' do
      uuids = [DataCycleCore::Classification.find_by(name: 'Bild').id]
      validator = subject.new(uuids, template_hash_required)
      assert_equal(no_error_hash, validator.error)
    end

    it 'successfully validates a universal classification' do
      uuids = [
        DataCycleCore::Classification.find_by(name: 'Bild').id,
        DataCycleCore::Classification.find_by(name: 'Video').id,
        DataCycleCore::Classification.find_by(name: 'Audio').id,
        DataCycleCore::Classification.find_by(name: 'Angebot').id
      ]
      validator = subject.new(uuids, template_hash_universal_classification)
      assert_equal(no_error_hash, validator.error)
    end

    it 'properly errors out for missing required values' do
      validator = subject.new([], template_hash_required)
      assert_equal(1, validator.error[:error].size)
    end

    it 'successfully validates with min, max given' do
      uuids = [DataCycleCore::Classification.find_by(name: 'Bild').id, DataCycleCore::Classification.find_by(name: 'Video').id]
      validator = subject.new(uuids, template_hash_length)
      assert_equal(no_error_hash, validator.error)
    end

    it 'properly errors out when length restrictions are not met' do
      data_cases = [
        [DataCycleCore::Classification.find_by(name: 'Bild').id],
        [
          DataCycleCore::Classification.find_by(name: 'Bild').id,
          DataCycleCore::Classification.find_by(name: 'Video').id,
          DataCycleCore::Classification.find_by(name: 'Audio').id,
          DataCycleCore::Classification.find_by(name: 'Angebot').id
        ]
      ]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash_length)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'errors out for invalid uuids given in an array' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      uuid2 = DataCycleCore::Classification.find_by(name: 'Video').id
      uuid3 = DataCycleCore::Classification.find_by(name: 'Audio').id
      validator = subject.new([uuid, uuid2, 3, uuid3], template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out if wrong tree_label is given for valid uuid' do
      new_template = template_hash.deep_dup
      new_template['tree_label'] = 'foo'
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      validator = subject.new(uuid, new_template)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out if universal classification receives an invalid uuid' do
      uuid = SecureRandom.uuid
      validator = subject.new([uuid], template_hash_universal_classification)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'errors out if wrong uuid-format is given' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      data_cases = [
        'abcde',
        ['abcde'],
        [uuid, 'abcde'],
        3.14
      ]
      data_cases.each do |case_item|
        validator = subject.new(case_item, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    it 'aggregates errors for several wrong uuids given' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      uuid2 = DataCycleCore::Classification.find_by(name: 'Video').id
      validator = subject.new([uuid, 'abcde', 'asödflkjasdfölkj', uuid2, 'aöslkfjasdöflj', 3, 'asödlkfasödkfj'], template_hash)
      assert_equal(5, validator.error[:error].values[0].size)
      assert_equal(0, validator.error[:warning].size)
    end

    it 'produces no warning when an unsupported keyword is used' do
      uuid = DataCycleCore::Classification.find_by(name: 'Bild').id
      new_template = template_hash_length.deep_dup.merge({ 'validations' => { 'maxi' => 3 } })
      validator = subject.new(uuid, new_template)
      assert_equal(0, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end
  end
end
