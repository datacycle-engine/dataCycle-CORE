# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Collection do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Collection
  end

  describe 'diffing collection uuid sets' do
    let(:template_hash) do
      { 'label' => 'Inhaltssammlung', 'type' => 'collection' }
    end

    it 'recognizes equivalent sets as no change' do
      uuid = SecureRandom.uuid

      [[nil, nil], [uuid, uuid], [[uuid], [uuid]], [[uuid], uuid]].each do |a, b|
        assert_nil(subject.new(a, b, template_hash).diff_hash)
      end
    end

    it 'recognizes a pure addition' do
      uuid = SecureRandom.uuid

      assert_equal([['+', [uuid]]], subject.new(nil, uuid, template_hash).diff_hash)
    end

    it 'recognizes a pure deletion' do
      uuid = SecureRandom.uuid

      assert_equal([['-', [uuid]]], subject.new(uuid, nil, template_hash).diff_hash)
    end

    it 'recognizes simultaneous additions and deletions' do
      uuid = SecureRandom.uuid
      uuid2 = SecureRandom.uuid

      assert_equal([['+', [uuid2]], ['-', [uuid]]], subject.new(uuid, uuid2, template_hash).diff_hash)
    end
  end
end
