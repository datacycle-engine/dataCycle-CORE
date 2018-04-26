require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::Validators::Linked do
  subject do
    DataCycleCore::MasterData::Validators::Linked
  end

  describe 'validate data' do
    let(:creator_hash) do
      {
        'label' => 'Ersteller',
        'type' => 'linked',
        'linked_table' => 'users',
        'validations' => {
          'max' => 1
        }
      }
    end

    let(:no_error_hash) do
      { error: {}, warning: {} }
    end

    let(:person1) do
      DataCycleCore::User.find_or_create_by!(email: 'person1@pixelpoint.at') do |item|
        item.given_name = 'Test'
        item.family_name = 'TEST'
        item.email = 'person1@pixelpoint.at'
        item.password = 'password'
        item.role_id = DataCycleCore::Role.find_by(rank: 5)&.id
      end
    end

    let(:person2) do
      DataCycleCore::User.find_or_create_by!(email: 'test2@pixelpoint.at') do |item|
        item.given_name = 'Test 2'
        item.family_name = 'TEST 2'
        item.password = 'password'
        item.role_id = DataCycleCore::Role.find_by(rank: 5)&.id
      end
    end

    it 'successfully validates linked User' do
      uuid = person1.id
      validator = subject.new([uuid], creator_hash)
      assert_equal(no_error_hash, validator.error)
    end

    it 'successfully validates more than one linked item' do
      template_hash = creator_hash.deep_dup.except('validations')
      uuid = person1.id
      uuid2 = person2.id
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

    it 'successfully validates linked items with min/max given' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'min' => 1, 'max' => 5 }
      uuid = person1.id
      uuid2 = person2.id
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

    it 'errors out when a wrong number of linked items are given' do
      template_hash = creator_hash.deep_dup
      template_hash['validations'] = { 'min' => 2, 'max' => 3 }
      uuid = person1.id
      uuid2 = person2.id
      uuid3 = DataCycleCore::User.find_or_create_by!(email: 'test3@pixelpoint.at') { |item|
        item.given_name = 'Test 3'
        item.family_name = 'TEST 3'
        item.password = 'password'
        item.role_id = DataCycleCore::Role.find_by(rank: 5)&.id
      }.id
      uuid4 = DataCycleCore::User.find_or_create_by!(email: 'test4@pixelpoint.at') { |item|
        item.given_name = 'Test 4'
        item.family_name = 'TEST 4'
        item.password = 'password'
        item.role_id = DataCycleCore::Role.find_by(rank: 5)&.id
      }.id
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
  end
end
