# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Normalizer::ActionParser do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Normalizer::ActionParser
  end

  describe 'action_parser' do
    let(:add) do
      { 'entryId' => '123xyz',
        'fieldsBefore' => [],
        'fieldsAfter' => [{ 'id' => 'SEX', 'type' => 'SEX', 'content' => 'M' }],
        'fieldsProposed' => [],
        'taskType' => 'ADD',
        'taskId' => 'Correction_SexForename',
        'taskPhase' => 'CORRECT' }
    end

    let(:alter) do
      { 'entryId' => '123xyz',
        'fieldsBefore' => [{ 'id' => 'COUNTRY', 'type' => 'COUNTRY', 'content' => 'Österreich' }],
        'fieldsAfter' => [{ 'id' => 'COUNTRY', 'type' => 'COUNTRY', 'content' => 'AT' }],
        'fieldsProposed' => [],
        'taskType' => 'ALTER',
        'taskId' => 'Norm_Country',
        'taskPhase' => 'NORM' }
    end

    let(:delete) do
      { 'entryId' => '123xyz',
        'fieldsBefore' => [{ 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '' }],
        'fieldsAfter' => [],
        'fieldsProposed' => [],
        'taskType' => 'DELETE',
        'taskId' => 'Cleanup_ALL_RemoveNullOrEmpty',
        'taskPhase' => 'CLEANUP' }
    end

    let(:split) do
      { 'entryId' => '123xyz',
        'fieldsBefore' => [{ 'id' => 'STREET', 'type' => 'STREET', 'content' => 'Ossiacher Zeile 30' }],
        'fieldsAfter' => [
          { 'id' => 'STREET', 'type' => 'STREET', 'content' => 'Ossiacher Zeile' },
          { 'id' => 'STREETNR', 'type' => 'STREETNR', 'content' => '30' }
        ],
        'fieldsProposed' => [],
        'taskType' => 'SPLIT',
        'taskId' => 'Split_StreetStreetnr',
        'taskPhase' => 'RESTRUCTURE' }
    end

    let(:split2) do
      { 'entryId' => '123xyz',
        'fieldsBefore' => [
          { 'id' => 'CITY', 'type' => 'CITY', 'content' => '9545 Radenthein' }
        ],
        'fieldsAfter' => [
          { 'id' => 'CITY', 'type' => 'CITY', 'content' => 'Radenthein' },
          { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9545' }
        ],
        'fieldsProposed' => [],
        'taskType' => 'SPLIT',
        'taskId' => 'Split_CityZip',
        'taskPhase' => 'RESTRUCTURE' }
    end

    let(:propose) do
      { 'entryId' => '123xyz',
        'fieldsBefore' => [],
        'fieldsAfter' => [],
        'fieldsProposed' => [
          { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9504' },
          { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9585' },
          { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9524' },
          { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9500' }
        ],
        'taskType' => 'PROPOSE',
        'taskId' => 'Correction_CountryCityZip',
        'taskPhase' => 'CORRECT' }
    end

    let(:error) do
      { 'entryId' => '123xyz',
        'fieldsBefore' => [],
        'fieldsAfter' => [],
        'fieldsProposed' => [],
        'taskType' => 'ERROR',
        'taskId' => 'Check_CountryZipCityStreet',
        'taskPhase' => 'VALIDATE',
        'message' => 'Unknown or Invalid address COUNTRY+ZIP+CITY+STREET' }
    end

    it 'parses addition correctly' do
      assert_equal([{ 'SEX' => ['+', 'M'] }], subject.add(add))
    end

    it 'parses changes correctly' do
      assert_equal([{ 'COUNTRY' => ['~', 'AT', 'Österreich'] }], subject.alter(alter))
    end

    it 'parses deletions correctly' do
      assert_equal([], subject.delete(delete))
    end

    it 'parses splits correctly' do
      assert_nil subject.split(split)
      assert_equal([{ 'CITY' => ['~', 'Radenthein', '9545 Radenthein'] }, { 'ZIP' => ['+', '9545'] }], subject.split(split2))
    end

    it 'parses suggestions correctly' do
      assert_equal([{ 'ZIP' => ['?', ['9504', '9585', '9524', '9500']] }], subject.propose(propose))
    end

    it 'parses errors correctly' do
      assert_equal([{ 'ERROR' => ['!', 'Unknown or Invalid address COUNTRY+ZIP+CITY+STREET'] }], subject.error(error))
    end
  end
end
