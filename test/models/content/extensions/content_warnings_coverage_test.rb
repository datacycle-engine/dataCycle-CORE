# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Extensions
      # Coverage for the ContentWarnings predicate helpers (content_warnings,
      # hard/soft/highlight checks) over the empty default warning set. Driven by a
      # host including the concern with no configured warnings, so no warning class
      # or content fixtures are needed.
      class ContentWarningsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        class WarningHost
          include DataCycleCore::Content::Extensions::ContentWarnings

          def template_name = 'TestThing'
        end

        test 'content warning predicates report an empty default warning set' do
          host = WarningHost.new

          DataCycleCore.stub(:content_warnings, {}) do
            assert_empty(host.content_warnings)
            assert_not(host.content_warnings?)
            assert_not(host.hard_content_warnings?)
            assert_not(host.soft_content_warnings?)
            assert_not(host.highlight_soft_content_warnings?)
            assert_not(host.highlight_hard_content_warnings?)
          end
        end
      end
    end
  end
end
