# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module ContentScore
      class CommonTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::ContentScore::Common
        end

        test 'by_cc_license scores 1 when all license classifications are creative commons' do
          content = license_content('https://creativecommons.org/licenses/by/4.0/')

          assert_equal(1, subject.by_cc_license(content:))
        end

        test 'by_cc_license scores 0 for a non creative commons license' do
          content = license_content('https://example.test/license')

          assert_equal(0, subject.by_cc_license(content:))
        end

        private

        def license_content(uri)
          relation = Class.new {
            def initialize(aliases) = (@aliases = aliases)
            def includes(*_args) = self
            def where(*_args) = @aliases
          }.new([struct_double(uri:)])

          Class.new {
            def initialize(relation) = (@relation = relation)
            def classification_aliases = @relation
            def properties_for(_key) = { 'tree_label' => 'Lizenzen' }
          }.new(relation)
        end
      end
    end
  end
end
