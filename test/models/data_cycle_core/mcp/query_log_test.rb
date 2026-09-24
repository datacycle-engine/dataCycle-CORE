# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the query history. The integration tests (mcp_global_tools_test) cover the
    # route through both mounts; what stands here are the properties that cannot be produced there:
    # that a failed log write does NOT turn the tool call into an error response, and the edge cases
    # without a user or without a hit count.
    class QueryLogTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      end

      setup do
        @user.activities.where(activity_type: DataCycleCore::Mcp::QueryLog::ACTIVITY_TYPE).delete_all
      end

      test 'record keeps tool, arguments and count -- the arguments are what makes a query repeatable' do
        record(tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: { query: 'Alpha' }, result: { count: 3, items: [] })

        entry = recent.first

        assert_equal 'search_contents', entry[:tool]
        assert_equal({ 'query' => 'Alpha' }, entry[:arguments])
        assert_equal 3, entry[:count]
      end

      test 'record stores the error of a failed call so it is not repeated blindly' do
        record(tool: DataCycleCore::Mcp::Tools::GetContent, arguments: { id: 'x' }, error: ActiveRecord::RecordNotFound.new('nope'))

        assert_equal 'nope', recent.first[:error]
      end

      # A tool without a hit count (get_content, elevation_profile) belongs in the history all the
      # same -- just without a number, rather than with an invented 0.
      test 'a result without a count is logged without one instead of as zero' do
        record(tool: DataCycleCore::Mcp::Tools::GetContent, arguments: { id: 'x' }, result: { id: 'x', title: 'y' })

        entry = recent.first

        assert_equal 'get_content', entry[:tool]
        assert_not entry.key?(:count)
      end

      test 'a string result is logged without a count' do
        record(tool: DataCycleCore::Mcp::Tools::GetContent, arguments: {}, result: 'plain text')

        assert_not recent.first.key?(:count)
      end

      # The instrumentation runs in Tools::Publication#to_mcp_tool INSIDE the rescue that builds the error
      # response. Without the rescue in QueryLog.record, a write failure in the history would replace
      # the tool's correct result with an error response -- the call then fails although there was
      # nothing wrong with the query.
      test 'a failing log write never turns a successful tool call into an error' do
        broken = Class.new {
          def log_request_activity(**)
            raise 'activities table is gone'
          end

          def nil? = false
        }.new

        assert_nothing_raised do
          DataCycleCore::Mcp::QueryLog.record(
            context: { current_user: broken },
            tool: DataCycleCore::Mcp::Tools::SearchContents,
            arguments: {},
            result: { count: 1 }
          )
        end
      end

      test 'nothing is logged without a user' do
        assert_nil DataCycleCore::Mcp::QueryLog.record(context: {}, tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: {})
        assert_empty DataCycleCore::Mcp::QueryLog.recent(user: nil, limit: 10)
      end

      # recent_queries reads the history and is therefore not itself a query that belongs in it.
      test 'a tool that opted out of the history is not recorded' do
        assert_not DataCycleCore::Mcp::Tools::RecentQueries.record_queries?

        record(tool: DataCycleCore::Mcp::Tools::RecentQueries, arguments: {})

        assert_empty recent
      end

      test 'every other tool is recorded by default' do
        tools = DataCycleCore::Mcp::Servers::GlobalServer::TOOLS - [DataCycleCore::Mcp::Tools::RecentQueries]

        assert_empty tools.reject(&:record_queries?).map(&:tool_name)
      end

      test 'recent returns the newest entry first' do
        record(tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: { query: 'first' })
        record(tool: DataCycleCore::Mcp::Tools::ListTemplates, arguments: {})

        assert_equal ['list_templates', 'search_contents'], recent.pluck(:tool)
      end

      test 'recent narrows to a single tool and honours the limit' do
        record(tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: { query: 'a' })
        record(tool: DataCycleCore::Mcp::Tools::ListTemplates, arguments: {})
        record(tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: { query: 'b' })

        assert_equal ['search_contents'], recent(tool: 'search_contents').pluck(:tool).uniq
        assert_equal 1, recent(limit: 1).size
      end

      # On the endpoint mount the entry hangs off the endpoint (as in the REST logging through
      # activitiable): that is what makes the scope a number was measured against readable from the
      # history. The same number means something different instance-wide than inside an endpoint.
      test 'an entry names the endpoint it was measured against' do
        endpoint = DataCycleCore::StoredFilter.create!(name: 'mcp query log test', user_id: @user.id, api: true)

        record(tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: {}, stored_filter: endpoint)

        assert_equal({ id: endpoint.id, name: endpoint.name }, recent.first[:endpoint])
      end

      test 'an instance-wide entry names no endpoint' do
        record(tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: {})

        assert_not recent.first.key?(:endpoint)
      end

      # The history is the user's own: another token's must not appear in it.
      test 'the history of another user is not visible' do
        other = DataCycleCore::User.find_by(email: 'guest@datacycle.at') || DataCycleCore::User.where.not(id: @user.id).first
        skip 'no second user available' if other.blank?

        record(tool: DataCycleCore::Mcp::Tools::SearchContents, arguments: { query: 'mine' })

        assert_empty(DataCycleCore::Mcp::QueryLog.recent(user: other, limit: 10).select { |e| e.dig(:arguments, 'query') == 'mine' })
      end

      private

      def record(tool:, arguments:, result: nil, error: nil, stored_filter: nil)
        DataCycleCore::Mcp::QueryLog.record(
          context: { current_user: @user, stored_filter: },
          tool:,
          arguments:,
          result:,
          error:
        )
      end

      def recent(limit: 10, tool: nil)
        DataCycleCore::Mcp::QueryLog.recent(user: @user, limit:, tool:)
      end
    end
  end
end
