# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Differs::Basic do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Differs::Basic
  end

  describe 'diff data' do
    it 'properly diffs integer' do
      assert_nil(subject.new(10, 10).diff_hash)
    end
  end
end
