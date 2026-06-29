# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::Credentials do
  include DataCycleCore::MinitestSpecHelper

  subject { DataCycleCore::Generic::Common::Transformations::Credentials }

  let(:external_source_id) { '11111111-1111-1111-1111-111111111111' }

  it 'returns data unchanged when no credential keys are present' do
    assert_equal({ 'a' => 1 }, subject.add_uc_credential_classifications({ 'a' => 1 }, external_source_id))
  end

  it 'adds universal_classification references for credential keys' do
    result = subject.add_uc_credential_classifications({ 'dc_credential_keys' => ['k1', 'k2'] }, external_source_id)

    assert_equal(2, result['universal_classifications'].size)
  end
end
