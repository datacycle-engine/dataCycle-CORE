# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Update
    # Coverage for the abstract Update::Base#update loop and its private Arel helpers.
    # A throwaway subclass supplies the abstract hooks (query/read/write/modify_content/
    # table_name) and a hand-built query double yields a single content item, so the
    # whole per-item update loop runs without touching the database.
    class BaseUpdateCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def build_updater(write_result:)
        content_item = Object.new
        content_item.define_singleton_method(:available_locales) { [:de] }
        content_item.define_singleton_method(:id) { 'content-id' }

        includes_result = Object.new
        includes_result.define_singleton_method(:find_each) { |&block| block.call(content_item) }

        query_double = Object.new
        query_double.define_singleton_method(:size) { 1 }
        query_double.define_singleton_method(:includes) { |*| includes_result }

        template = Object.new
        template.define_singleton_method(:template_name) { 'TestThing' }

        Class.new(DataCycleCore::Update::Base) {
          define_method(:initialize) do
            @query_double = query_double
            @template = template
            @write_result = write_result
            @reads = []
            @modified = []
          end

          attr_reader :reads, :modified

          define_method(:query) { @query_double }
          define_method(:modify_content) { |item| @modified << item }
          define_method(:write) { |_item, _data_hash, _time| @write_result }
          define_method(:table_name) { 'things' }

          define_method(:read) do |item|
            @reads << item
            { 'name' => 'value' }
          end
        }.new
      end

      test 'update reads, modifies and writes every content item / locale' do
        updater = build_updater(write_result: { error: nil })

        capture_io { updater.update }

        assert_equal 1, updater.reads.size
        assert_equal 1, updater.modified.size
      end

      test 'update logs the context when write returns an error' do
        updater = build_updater(write_result: { error: 'boom' })

        out, = capture_io { updater.update }

        assert_match 'things(content-id)', out
      end

      test 'quoted and json_path build Arel nodes' do
        updater = build_updater(write_result: { error: nil })

        quoted = updater.send(:quoted, 'value')
        node = updater.send(:json_path, Arel::Table.new(:things)[:metadata], quoted)

        assert_not_nil quoted
        assert_kind_of Arel::Nodes::InfixOperation, node
      end
    end
  end
end
