# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/db_helper'

module DataCycleCore
  class DbHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'ensure_format keeps valid pg_dump formats' do
      ['c', 'p', 't', 'd'].each do |format|
        assert_equal format, DbHelper.ensure_format(format)
      end
    end

    test 'ensure_format maps a known suffix to its format' do
      assert_equal 'p', DbHelper.ensure_format('sql')
      assert_equal 'c', DbHelper.ensure_format('dump')
    end

    test 'ensure_format falls back to directory format for unknown input' do
      assert_equal 'd', DbHelper.ensure_format('something')
    end

    test 'suffix_for_format returns the file suffix for a format' do
      assert_equal 'dump', DbHelper.suffix_for_format('c')
      assert_equal 'sql', DbHelper.suffix_for_format('p')
      assert_nil DbHelper.suffix_for_format('x')
    end

    test 'format_for_file detects the format from the file extension' do
      assert_equal 'c', DbHelper.format_for_file('backup.dump')
      assert_equal 'p', DbHelper.format_for_file('backup.sql')
      assert_equal 'd', DbHelper.format_for_file('backup.dir')
      assert_equal 't', DbHelper.format_for_file('backup.tar')
      assert_nil DbHelper.format_for_file('backup.unknown')
    end

    test 'backup_directory returns the backups path without creating it' do
      assert_equal Rails.root.join('db', 'backups').to_s, DbHelper.backup_directory.to_s
      assert_equal Rails.root.join('db', 'backups', 'sub').to_s, DbHelper.backup_directory('sub').to_s
    end

    test 'backup_directory creates the directory when requested' do
      suffix = 'db_helper_test_tmp'
      target = Rails.root.join('db', 'backups', suffix)
      FileUtils.rm_rf(target)

      capture_io do
        assert_equal target.to_s, DbHelper.backup_directory(suffix, create: true).to_s
        assert Dir.exist?(target)
        # second call hits the already-existing branch
        DbHelper.backup_directory(suffix, create: true)
      end
    ensure
      FileUtils.rm_rf(target)
    end

    test 'with_config yields the database connection details' do
      values = nil
      DbHelper.with_config { |config| values = config }

      assert_equal 5, values.size
      assert_includes values, Rails.application.config.database_configuration[Rails.env]['database']
    end

    test 'status_relation reports ok and error states' do
      ok, = capture_io { DbHelper.status_relation(0, 'things', 'classifications') }

      assert_includes ok, '[OK]'

      error, = capture_io { DbHelper.status_relation(3, 'things', 'classifications') }

      assert_includes error, '[ERROR]'
    end
  end
end
