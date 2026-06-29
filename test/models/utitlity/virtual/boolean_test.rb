# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class BooleanTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Boolean
        end

        test 'by_assigned_classification is true when a classification matches the configured path' do
          content = struct_double(full_classification_aliases: [struct_double(full_path: 'Lizenzen > CC0'), struct_double(full_path: 'Tags > A')])

          assert(subject.by_assigned_classification(content:, virtual_definition: { 'virtual' => { 'path' => 'Lizenzen > CC0' } }))
        end

        test 'by_assigned_classification is false when no classification matches' do
          content = struct_double(full_classification_aliases: [struct_double(full_path: 'Tags > A')])

          assert_not(subject.by_assigned_classification(content:, virtual_definition: { 'virtual' => { 'path' => 'Lizenzen > CC0' } }))
        end
      end
    end
  end
end
