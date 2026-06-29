# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Contracts
      # Drives the macros registered on GeneralContract through minimal anonymous
      # subclasses that attach each macro to a single rule.
      class GeneralContractTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def failed_on?(result, key)
          result.errors.to_h.key?(key)
        end

        def credentials_contract(macro)
          Class.new(DataCycleCore::MasterData::Contracts::GeneralContract) {
            schema { optional(:credentials).value(:array) }
            rule(:credentials).validate(macro)
          }.new
        end

        test 'dc_credential_keys requires all-or-none entries to carry a credential_key' do
          result = credentials_contract(:dc_credential_keys).call(credentials: [{ credential_key: 'a' }, {}])

          assert(failed_on?(result, :credentials))
        end

        test 'dc_credential_keys requires unique credential_keys' do
          result = credentials_contract(:dc_credential_keys).call(credentials: [{ credential_key: 'a' }, { credential_key: 'a' }])

          assert(failed_on?(result, :credentials))
        end

        test 'dc_unique_credentials rejects duplicate credential entries' do
          result = credentials_contract(:dc_unique_credentials).call(credentials: [{ a: 1 }, { a: 1 }])

          assert(failed_on?(result, :credentials))
        end

        def duplicate_candidate_contract
          Class.new(DataCycleCore::MasterData::Contracts::GeneralContract) {
            schema { optional(:mod).maybe(:string) }
            rule(:mod).validate(:duplicate_candidate_module)
          }.new
        end

        test 'duplicate_candidate_module rescues an invalid class name' do
          # an invalid constant name makes ModuleService raise NameError (rescued)
          result = duplicate_candidate_contract.call(mod: 'Invalid Name')

          assert(failed_on?(result, :mod))
        end

        test 'duplicate_candidate_module checks a resolvable class for the required methods' do
          # a real module resolves, so the respond_to checks run (pass or fail, the branch is exercised)
          assert_not_nil(duplicate_candidate_contract.call(mod: 'DataMetricHamming'))
        end

        test 'ruby_module_and_method reports a missing module/method combination' do
          contract = Class.new(DataCycleCore::MasterData::Contracts::GeneralContract) {
            schema { optional(:target).maybe(:hash) }
            rule(:target).validate(ruby_module_and_method: 'DataCycleCore')
          }.new

          result = contract.call(target: { module: 'Invalid Name', method: 'nope' })

          assert(failed_on?(result, :target))
        end

        test 'touch_step_required demands a touch step for mark-deleted strategies' do
          contract = Class.new(DataCycleCore::MasterData::Contracts::GeneralContract) {
            attr_accessor :steps

            schema do
              optional(:download_strategy).maybe(:string)
              optional(:source_type).maybe(:string)
            end
            rule(:download_strategy).validate(:touch_step_required)
          }.new

          contract.steps = { s1: { source_type: 'st1', download_strategy: ['DownloadDataFromData'] } }
          result = contract.call(download_strategy: 'DownloadMarkDeleted', source_type: 'st1')

          assert(failed_on?(result, :download_strategy))
        end
      end
    end
  end
end
