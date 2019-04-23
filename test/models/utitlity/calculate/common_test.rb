# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Utility::Compute::Common do
  subject do
    DataCycleCore::Utility::Compute::Common
  end

  describe 'testing Common method: copy' do
    it 'copy string value' do
      assert_equal('test', subject.copy({ computed_parameters: ['test'] }))
    end

    it 'copy empty string value' do
      assert_equal('', subject.copy({ computed_parameters: '' }))
    end

    it 'copy nil value' do
      assert_nil(subject.copy({ computed_parameters: nil }))
    end
  end
end
