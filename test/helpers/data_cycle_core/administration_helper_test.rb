# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class AdministrationHelperTest < ActionView::TestCase
    include DataCycleCore::AdministrationHelper
    include DataCycleCore::UiLocaleHelper

    test 'import_data_time localizes a time and passes other values through' do
      assert_equal '15.01.2024 09:30', import_data_time(Time.zone.local(2024, 1, 15, 9, 30))
      assert_equal 'never', import_data_time('never')
      assert_nil import_data_time(nil)
    end

    test 'active_duration is nil when there is neither a duration nor a running job' do
      assert_nil active_duration({}, 'download')
    end

    test 'active_duration describes a finished job duration' do
      result = active_duration({ last_download_time: 120, last_download_status: 'finished' }, 'download')

      assert_match(/\A \(.*\)\z/, result)
    end

    test 'active_duration describes a running job duration' do
      result = active_duration({ last_download: Time.zone.now - 90, last_download_status: 'running' }, 'download')

      assert_match(/\A \(.*\)\z/, result)
    end

    test 'timestamp_tooltip is blank when the timestamp is missing' do
      assert_predicate timestamp_tooltip({}, 'download'), :blank?
    end

    test 'timestamp_tooltip renders the titleized type and the timestamp' do
      html = timestamp_tooltip({ last_download: Time.zone.local(2024, 1, 15, 9, 30), last_download_status: 'finished', last_download_time: 60 }, 'download')

      assert_includes html, 'Download'
      assert_includes html, '15.01.2024 09:30'
    end

    test 'import_schedule is nil for a blank schedule' do
      assert_nil import_schedule(nil)
      assert_nil import_schedule([])
    end

    test 'import_schedule renders a tooltip with the schedule header' do
      html = import_schedule([{ timestamp: 'not-an-eotime' }])

      assert_includes html, 'import-schedule-tooltip'
      assert_includes html, '...'
    end

    test 'job_title_tooltip returns a bold title without jobs' do
      assert_equal '<b>Import</b>', job_title_tooltip('Import', nil)
    end

    test 'job_title_tooltip lists the jobs below the title' do
      html = job_title_tooltip('Import', { 'queued' => 3, 'running' => 1 })

      assert_includes html, 'Import:'
      assert_includes html, 'queued: 3'
      assert_includes html, 'running: 1'
    end
  end
end
