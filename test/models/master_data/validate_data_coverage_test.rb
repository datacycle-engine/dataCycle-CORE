# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    # Coverage for ValidateData's early-exit branches: blank data (strict error vs.
    # non-strict warning), a blank validation hash, and the valid? strict/non-strict
    # result reductions. Pure in-memory, no template or content needed.
    class ValidateDataCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def validator
        DataCycleCore::MasterData::ValidateData.new
      end

      test 'validate records a strict error when the data is blank' do
        result = validator.validate(nil, { 'name' => 'Artikel' }, true)

        assert_predicate(result[:error], :present?)
      end

      test 'validate records a warning when the data is blank and not strict' do
        result = validator.validate(nil, { 'name' => 'Artikel' }, false)

        assert_predicate(result[:warning], :present?)
      end

      test 'validate records an error when the validation hash is blank' do
        result = validator.validate({ 'name' => 'x' }, {}, false)

        assert_predicate(result[:error], :present?)
      end

      test 'valid? is false in strict mode when validation produced messages' do
        assert_not(validator.valid?(nil, { 'name' => 'Artikel' }, true))
      end

      test 'valid? ignores warnings in non-strict mode' do
        assert(validator.valid?(nil, { 'name' => 'Artikel' }, false))
      end
    end
  end
end
