# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CollectionTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @collection = DataCycleCore::TestPreparations.create_watch_list(name: 'Inhaltssammlung 1')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1 in Collection' }, prevent_history: true)
      @content.watch_lists << @collection
    end

    test 'user has my_selection' do
      user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')

      assert user.my_selection
    end

    test 'clear_if_not_active does not clear normal collection' do
      @collection.clear_if_not_active

      assert_equal 1, @collection.reload.things.size
    end

    test 'clear_if_not_active does not clear my_selection with active contents' do
      @collection.update_column(:my_selection, true)

      @collection.clear_if_not_active

      assert_equal 1, @collection.reload.things.size
    end

    test 'clear_if_not_active does clear my_selection after 12 hours' do
      @collection.update_column(:my_selection, true)

      @collection.watch_list_data_hashes.first.update_column(:updated_at, 13.hours.ago)

      @collection.clear_if_not_active

      assert_equal 0, @collection.reload.things.size
    end

    test 'by_id_name_slug_description returns all for a blank value' do
      assert_equal DataCycleCore::Collection.count, DataCycleCore::Collection.by_id_name_slug_description('').count
    end

    test 'by_id_name_slug_description finds a collection by uuid' do
      assert_includes DataCycleCore::Collection.by_id_name_slug_description(@collection.id).to_a, @collection
    end

    test 'by_id_name_slug_description searches by text' do
      assert_kind_of Array, DataCycleCore::Collection.by_id_name_slug_description('Inhaltssammlung').to_a
    end

    test 'by_id_or_name matches uuids and names' do
      result = DataCycleCore::Collection.by_id_or_name([@collection.id, 'Inhaltssammlung 1']).to_a

      assert_includes result, @collection
    end

    test 'by_id_or_name returns none for a blank value' do
      assert_empty DataCycleCore::Collection.by_id_or_name(nil).to_a
    end

    test 'by_id_name_slug matches uuids, slugs and names' do
      result = DataCycleCore::Collection.by_id_name_slug([@collection.id, 'Inhaltssammlung 1']).to_a

      assert_includes result, @collection
    end

    test 'accessible_by_subclass unions accessible records across subclasses' do
      ability = DataCycleCore::Ability.new(@admin)

      assert_kind_of Array, DataCycleCore::Collection.accessible_by_subclass(ability).to_a
    end

    test 'valid_write_links? is false without writable data links' do
      assert_not @collection.valid_write_links?
    end

    test 'shared_with_user? is false for a nil user' do
      assert_not @collection.shared_with_user?(nil)
    end

    test 'shared_with_user? is false when the collection is not shared with the user' do
      assert_not @collection.shared_with_user?(@admin)
    end

    test 'things returns a search query relation' do
      assert DataCycleCore::Collection.things
    end

    test 'api_v4_type is Collection' do
      assert_equal 'Collection', DataCycleCore::Collection.new.api_v4_type
    end

    test 'update_description_stripped strips html on save' do
      watch_list = DataCycleCore::WatchList.create!(full_path: 'Collection Desc WL', user: @admin, description: '<b>Hello</b> world')

      assert_equal 'Hello world', watch_list.description_stripped
    end
  end
end
