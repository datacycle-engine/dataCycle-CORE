# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    class HistoryListEntryTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def entry(**args)
        DataCycleCore::Content::HistoryListEntry.new(**args)
      end

      test 'initializes attributes from an item' do
        content = create_content('Artikel', { name: 'HLE Article' })
        user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')

        result = entry(item: content, user:, locales: [:de])

        assert_equal(content.id, result.id)
        assert_equal('DataCycleCore::Thing', result.class_name)
        assert_equal('de', result.locale)
      end

      test 'path_id and path_history_id depend on right_side' do
        left = entry(id: 'A', diff_id: 'B', right_side: false)

        assert_equal('B', left.path_id)
        assert_equal('A', left.path_history_id)

        right = entry(id: 'A', diff_id: 'B', right_side: true)

        assert_equal('A', right.path_id)
        assert_equal('B', right.path_history_id)
      end

      test 'history_thing_path_params builds the route params' do
        result = entry(id: 'A', diff_id: 'B', watch_list_id: 'W', right_side: false)
        content = Struct.new(:id).new('C')

        assert_equal({ id: 'B', history_id: 'A', watch_list_id: 'W' }, result.history_thing_path_params(content))
      end

      test 'history_thing_path_params falls back to the content id' do
        result = entry(id: nil, diff_id: nil, right_side: false)
        content = Struct.new(:id).new('C')

        assert_equal('C', result.history_thing_path_params(content)[:id])
      end

      test 'active? and active_class reflect the active and diff ids' do
        active = entry(id: 'A', active_id: 'A', diff_id: 'X')

        assert_predicate(active, :active?)
        assert_equal('active', active.active_class)

        diff = entry(id: 'A', active_id: 'X', diff_id: 'A')

        assert_predicate(diff, :active?)
        assert_equal('diff-active', diff.active_class)

        neither = entry(id: 'A', active_id: 'X', diff_id: 'Y')

        assert_not(neither.active?)
        assert_nil(neither.active_class)
      end

      test 'icon shows source and target arrows for the active diff sides' do
        source = entry(id: 'A', active_id: 'A', diff_id: 'A', diff_view: true, right_side: false)

        assert_predicate(source, :source_icon?)
        assert_equal('fa fa-long-arrow-left', source.icon[:class])

        target = entry(id: 'A', active_id: 'X', diff_id: 'A', diff_view: true, right_side: false)

        assert_predicate(target, :target_icon?)
        assert_equal('fa fa-long-arrow-right', target.icon[:class])
      end

      test 'icon offers use-as-source/target actions outside an active diff' do
        as_source = entry(id: 'A', active_id: 'X', diff_id: 'Y', diff_view: true, icon_only: false, right_side: false)

        assert_equal('fa fa-long-arrow-left', as_source.icon[:class])

        as_target = entry(id: 'A', active_id: 'X', diff_id: 'Y', diff_view: true, icon_only: false, right_side: true)

        assert_equal('fa fa-long-arrow-right', as_target.icon[:class])
      end

      test 'icon falls back to the stored icon outside diff view' do
        result = entry(id: 'A', icon: { class: 'custom' }, diff_view: false)

        assert_equal({ class: 'custom' }, result.icon)
      end
    end
  end
end
