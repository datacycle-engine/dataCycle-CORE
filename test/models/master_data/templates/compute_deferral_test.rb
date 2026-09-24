# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Templates
      # [#51643] The one classification of :compute: :async: / :after_save: into an order, read by
      # Content's three computed-property selectors, TemplateValidator and Extensions::Generated.
      class ComputeDeferralTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def compute(**flags)
          { 'compute' => { 'module' => 'Common', 'method' => 'copy' }.merge(flags) }
        end

        test 'a property without a compute has no deferral' do
          assert_nil(ComputeDeferral.of({ 'type' => 'string' }))
          assert_nil(ComputeDeferral.of(nil))
        end

        test 'a compute defaults to inline and each flag names its own deferral' do
          assert_equal('inline', ComputeDeferral.of(compute))
          assert_equal('after_save', ComputeDeferral.of(compute('after_save' => true)))
          assert_equal('async', ComputeDeferral.of(compute('async' => true)))
        end

        # The transformed templates carry the flags as they were written in YAML, where :async: true
        # and :async: 'true' both occur.
        test 'a flag counts whether it is written as a boolean or as a string' do
          assert(ComputeDeferral.async?(compute('async' => 'true')))
          assert_not(ComputeDeferral.async?(compute('async' => false)))
        end

        # :async: wins, because Extensions::Generated#defer_generated_compute! only sets it on a
        # companion that declares neither, so the two never contradict each other by accident.
        test 'a compute declaring both flags is the later of the two' do
          assert_equal('async', ComputeDeferral.of(compute('async' => true, 'after_save' => true)))
        end

        test 'later? compares two computes and ignores a parameter carrying none' do
          assert(ComputeDeferral.later?(compute('async' => true), than: compute))
          assert_not(ComputeDeferral.later?(compute, than: compute('async' => true)))
          assert_not(ComputeDeferral.later?(compute, than: compute))
          assert_not(ComputeDeferral.later?({ 'type' => 'string' }, than: compute))
          assert_not(ComputeDeferral.later?(compute('async' => true), than: { 'type' => 'string' }))
        end
      end
    end
  end
end
