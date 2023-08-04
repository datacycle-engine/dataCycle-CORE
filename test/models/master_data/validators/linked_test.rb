# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LinkedTest < ActiveSupport::TestCase
    def subject
      DataCycleCore::MasterData::Validators::Linked
    end

    def setup
      @person1 = create_content('Person', DataCycleCore::TestPreparations.load_dummy_data_hash(:persons, :person1))
      @person2 = create_content('Person', DataCycleCore::TestPreparations.load_dummy_data_hash(:persons, :person2))
    end

    def create_content(template_name, data = {})
      DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data)
    end

    def creator_hash
      {
        'label' => 'Ersteller',
        'type' => 'linked',
        'template_name' => 'Bild',
        'validations' => {
          'max' => 1
        }
      }
    end

    def no_error_hash
      { error: {}, warning: {} }
    end

    test 'successfully validates linked User' do
      uuid = @person1.id
      validator = subject.new([uuid], creator_hash)
      assert_equal(no_error_hash, validator.error)
    end

    test 'successfully validates more than one linked item' do
      template_hash = creator_hash.deep_dup.except('validations')
      uuid = @person1.id
      uuid2 = @person2.id
      data_cases = [
        uuid,
        [uuid],
        [uuid, uuid2]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    test 'successfully validates linked items with min/max given' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'min' => 1, 'max' => 5 }
      uuid = @person1.id
      uuid2 = @person2.id
      data_cases = [
        uuid,
        [uuid],
        [uuid, uuid2]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    test 'errors out if a wrong data type is given' do
      template_hash = creator_hash.deep_dup
      data_cases = [
        3,
        6.14,
        Time.zone.now
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    test 'errors out if a wrong keyword is given' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'maxi' => 5 }
      validator = subject.new(SecureRandom.uuid, template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    test 'errors out if an invalid uuid is given in an array' do
      template_hash = creator_hash.deep_dup
      validator = subject.new([SecureRandom.uuid, 5], template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    test 'errors out when a wrong number of linked items are given' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'min' => 2, 'max' => 3 }
      uuid = @person1.id
      uuid2 = @person2.id
      uuid3 = SecureRandom.uuid
      uuid4 = SecureRandom.uuid
      data_cases = [
        uuid,
        [uuid],
        [uuid, uuid2, uuid3, uuid4]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, template_hash)
        assert_equal(1, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end

    test 'errors out when no data is given for a required field' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'required' => true }
      validator = subject.new(nil, template_hash)
      assert_equal(1, validator.error[:error].size)
      assert_equal(0, validator.error[:warning].size)
    end

    test 'soft_min for linked items' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'soft_min' => 2 }
      uuid = @person1.id
      data_cases = [
        uuid,
        [uuid]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(1, validator.error[:warning].size)
      end
    end

    test 'soft_max for linked items' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'soft_max' => 1 }
      uuid = @person1.id
      uuid2 = @person2.id
      data_cases = [
        [uuid, uuid2]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(1, validator.error[:warning].size)
      end
    end

    test 'soft_required for linked items' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'soft_required' => true }
      uuid = @person1.id
      uuid2 = @person2.id
      data_cases = [
        uuid,
        [uuid],
        [uuid, uuid2]
      ]
      data_cases.each do |item_case|
        validator = subject.new(item_case, template_hash)
        assert_equal(0, validator.error[:error].size)
        assert_equal(0, validator.error[:warning].size)
      end
    end
  end
end
