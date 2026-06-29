# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module MasterData
    module Templates
      # Coverage for TemplateStatistics. The seeded templates all predate the run start
      # time, so update_statistics collects them (with their thing / history counts) and
      # render_statistics prints the report table; output is captured so it does not
      # pollute the test log.
      class TemplateStatisticsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        test 'update_statistics collects outdated templates and render prints the table' do
          stats = DataCycleCore::MasterData::Templates::TemplateStatistics.new
          stats.update_statistics

          assert_not_empty stats.outdated_templates

          out, = capture_io { stats.render_statistics }

          assert_match 'template_name', out
        end
      end
    end
  end
end
