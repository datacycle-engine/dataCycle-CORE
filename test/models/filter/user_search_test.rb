# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UserSearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @creator = DataCycleCore::User.create!(given_name: 'T', family_name: 'E', email: 't1@t.at', password: 'password')
      @editor1 = DataCycleCore::User.create!(given_name: 'T', family_name: 'E', email: 't2@t.at', password: 'password')
      @editor2 = DataCycleCore::User.create!(given_name: 'T', family_name: 'E', email: 't3@t.at', password: 'password')
      content1 = create_content('Artikel', { name: 'HEADLINE 1' })
      update_content_partially(content1, { name: 'HEADLINE 11' }, @editor1)
      update_content_partially(content1, { name: 'HEADLINE 12' }, @editor2)
      content2 = create_content('Artikel', { name: 'HEADLINE 2' })
      update_content_partially(content2, { name: 'HEADLINE 21' }, @editor1)
      create_content('Artikel', { name: 'HEADLINE 3' })
    end

    test 'filter contents based on creator' do
      items = DataCycleCore::Filter::Search.new(:de).user(@creator.id, 'creator')
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_user(@creator.id, 'creator')
      assert_equal(0, items.count)
    end

    test 'filter contents based on last editor' do
      items = DataCycleCore::Filter::Search.new(:de).user(@editor2.id, 'last_editor')
      assert_equal(1, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_user(@editor2.id, 'last_editor')
      assert_equal(2, items.count)
    end

    test 'filter contents based on all editors' do
      items = DataCycleCore::Filter::Search.new(:de).user(@editor1.id, 'editor')
      assert_equal(2, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_user(@editor1.id, 'editor')
      assert_equal(1, items.count)
    end

    test 'filter contents based on any creator as user' do
      items = DataCycleCore::Filter::Search.new(:de).exists_user(nil, 'creator')
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_exists_user(nil, 'creator')
      assert_equal(0, items.count)
    end

    test 'filter contents based on any editor as user' do
      items = DataCycleCore::Filter::Search.new(:de).exists_user(nil, 'editor')
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_exists_user(nil, 'editor')
      assert_equal(0, items.count)
    end

    test 'filter contents based on like creator as user' do
      items = DataCycleCore::Filter::Search.new(:de).like_user({ 'text' => 't1@t.at' }, 'creator')
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_like_user({ 'text' => 't1@t.at' }, 'creator')
      assert_equal(0, items.count)
    end

    test 'filter contents based on like editor as user' do
      items = DataCycleCore::Filter::Search.new(:de).like_user({ 'text' => 't1@t.at' }, 'editor')
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_like_user({ 'text' => 't1@t.at' }, 'editor')
      assert_equal(0, items.count)
    end

    test 'filter contents based on like last_editor as user' do
      items = DataCycleCore::Filter::Search.new(:de).like_user({ 'text' => 't1@t.at' }, 'last_editor')
      assert_equal(1, items.count)

      items = DataCycleCore::Filter::Search.new(:de).like_user({ 'text' => 't.at' }, 'last_editor')
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_like_user({ 'text' => 't1@t.at' }, 'last_editor')
      assert_equal(2, items.count)
    end

    private

    def create_content(template_name, data = {})
      DataCycleCore::TestPreparations.create_content(template_name:, data_hash: data, user: @creator)
    end

    def update_content_partially(content, data = {}, user = nil)
      content.set_data_hash(data_hash: data, current_user: user)
    end
  end
end
