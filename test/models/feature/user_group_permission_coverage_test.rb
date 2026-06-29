# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for the UserGroupPermission feature - ability_selection / default_role /
    # create_permission_option, driven over a stubbed configuration and a view double so
    # the option building runs without a real feature config or database. reload is left
    # out as it mutates the shared PermissionsList.
    class UserGroupPermissionCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Feature::UserGroupPermission

      def view_double(locale: 'de')
        view = Object.new
        view.define_singleton_method(:active_ui_locale) { locale }
        view
      end

      test 'ability_selection returns [] without a view and builds an option per ability otherwise' do
        config = { 'abilities' => { 'thing' => { 'actions' => ['read', 'update'] }, 'asset' => { 'actions' => ['read'] } } }

        Subject.stub(:configuration, config) do
          assert_equal [], Subject.ability_selection(nil)

          options = Subject.ability_selection(view_double)

          assert_equal 2, options.size
          assert(options.all? { |option| option.is_a?(Array) && option.size == 2 })
        end
      end

      test 'create_permission_option returns nil when actions are missing' do
        Subject.stub(:configuration, { 'abilities' => {} }) do
          assert_nil Subject.send(:create_permission_option, 'thing', nil)
          assert_nil Subject.send(:create_permission_option, 'thing', { 'label' => 'x' })
        end
      end

      test "default_role keeps 'all' verbatim and symbolizes any other role" do
        Subject.stub(:configuration, { 'default_role' => 'all' }) do
          assert_equal 'all', Subject.default_role
        end

        Subject.stub(:configuration, { 'default_role' => 'editor' }) do
          assert_equal :editor, Subject.default_role
        end
      end
    end
  end
end
