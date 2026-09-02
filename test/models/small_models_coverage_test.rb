# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for small model/value classes that were left just below 90%:
  # readonly? view models, asset extension_white_lists, the AsJsonExtension mixin,
  # the Warning::Base message helper, Webhook::Refresh, the NamedVersion ability,
  # ClassificationAliasPathsTransitive query builders and CollectionConfiguration#update_slug.
  class SmallModelsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # NOTE: ContentMetaItem / ContentProperties / CollectionConfiguration are backed by
    # tables/views that are not present in the core test schema, so they cannot be
    # instantiated here and stay below 90% in core.
    test 'DataLinkContentItem (content_items view) is readonly' do
      assert_predicate DataCycleCore::DataLinkContentItem.new, :readonly?
    end

    test 'asset subclasses expose an extension white list from config' do
      assert_kind_of Array, DataCycleCore::DataCycleFile.extension_white_list
      assert_includes DataCycleCore::SrtFile.extension_white_list, 'srt'
    end

    test 'AsJsonExtension camelizes keys only when requested' do
      host = Class.new {
        include DataCycleCore::Common::AsJsonExtension

        def initialize
          @first_name = 'John'
        end
      }.new

      assert_equal({ 'first_name' => 'John' }, host.as_json)
      assert_equal({ 'firstName' => 'John' }, host.as_json(camelize_keys: true))
    end

    test 'Warning::Base builds a dotted message path' do
      message = DataCycleCore::Warning::Base.message('too_long', nil, nil)

      assert_equal 'data_cycle_core.warning.base.too_long', message[:path]
    end

    test 'Webhook::Refresh delegates execute_all with the refresh action' do
      captured = nil
      DataCycleCore::Webhook::Base.stub(:execute_all, ->(_data, action, **) { captured = action }) do
        DataCycleCore::Webhook::Refresh.execute_all({})
      end

      assert_equal 'refresh', captured
    end

    test 'NamedVersion ability grants remove_version_name for rank 10 users' do
      user = Object.new
      user.define_singleton_method(:has_rank?) { |*| true }

      ability = DataCycleCore::Feature::Abilities::NamedVersion.new(user)

      assert ability.can?(:remove_version_name, DataCycleCore::Thing)
    end

    test 'ClassificationAliasPathsTransitive query builders run over the relation' do
      assert_equal 0, DataCycleCore::ClassificationAliasPathsTransitive.classification_aliases.count
      assert_equal 0, DataCycleCore::ClassificationAliasPathsTransitive.mapped_classification_aliases.count
    end

    test 'Download.temp_token writes a cache token and remove_token deletes it' do
      user = struct_double(id: SecureRandom.uuid)
      token = DataCycleCore::Download.temp_token(user:)

      assert_kind_of String, token
      assert_equal user.id, Rails.cache.read("download_#{token}")

      DataCycleCore::Download.remove_token(key: "download_#{token}")

      assert_nil Rails.cache.read("download_#{token}")
    end

    test 'Callbacks registers blocks via method_missing and executes them' do
      proxy = DataCycleCore::Callbacks.new(->(cb) { cb.on_save { 'saved' } })
      proxy.on_delete { 'deleted' }

      assert_equal ['saved'], proxy.execute_callback(:on_save)
      assert_equal ['deleted'], proxy.execute_callback(:on_delete)
      assert_nil proxy.execute_callback(:never_registered)

      error = assert_raises(RuntimeError) { proxy.some_callback('arg') }
      assert_match(/wrong number of arguments/, error.message)
    end

    test 'UserGroupUser#notify_unlocked_users returns early when the issuer is blank' do
      user_group_user = DataCycleCore::UserGroupUser.new

      user_group_user.stub(:user_group, struct_double(name: 'grp')) do
        DataCycleCore::Feature::UserApi.stub(:new_user_confirmations_issuer, nil) do
          assert_nil user_group_user.send(:notify_unlocked_users)
        end
      end
    end

    test 'UserGroupUser#notify_unlocked_users notifies the confirmed user for a present issuer' do
      notified = false
      feature = Object.new
      feature.define_singleton_method(:current_issuer=) { |_v| nil }
      feature.define_singleton_method(:notify_confirmed_user) { notified = true }
      user_group_user = DataCycleCore::UserGroupUser.new

      user_group_user.stub(:user_group, struct_double(name: 'grp')) do
        user_group_user.stub(:user, struct_double(user_api_feature: feature)) do
          DataCycleCore::Feature::UserApi.stub(:new_user_confirmations_issuer, 'issuer-1') do
            user_group_user.send(:notify_unlocked_users)
          end
        end
      end

      assert notified
    end

    test 'ContentContent::Link.id_attribute_hash groups relations by dependent id' do
      relation = Object.new
      relation.define_singleton_method(:where) { |*| self }
      relation.define_singleton_method(:distinct) { self }
      relation.define_singleton_method(:pluck) { |*| [['a', 'rel1'], ['a', 'rel2'], ['b', 'rel1']] }

      result = DataCycleCore::ContentContent::Link.stub(:with_relation, relation) do
        DataCycleCore::ContentContent::Link.id_attribute_hash('content-b')
      end

      assert_equal({ 'a' => ['rel1', 'rel2'], 'b' => ['rel1'] }, result)
    end

    test 'ContentContent::Link.id_attribute_hash returns an empty hash without dependents' do
      assert_empty DataCycleCore::ContentContent::Link.id_attribute_hash(SecureRandom.uuid)
    end

    test 'ClassificationContent class scopes build relations' do
      id = SecureRandom.uuid

      assert_kind_of ActiveRecord::Relation, DataCycleCore::ClassificationContent.with_content(id)
      assert_kind_of ActiveRecord::Relation, DataCycleCore::ClassificationContent.with_relation('x')
      assert_kind_of ActiveRecord::Relation, DataCycleCore::ClassificationContent.with_classification_ids([id])
      assert_kind_of ActiveRecord::Relation, DataCycleCore::ClassificationContent.classifications
    end

    test 'CollectedClassificationContent is readonly and exposes concepts' do
      assert_predicate DataCycleCore::CollectedClassificationContent.new, :readonly?
      assert_kind_of ActiveRecord::Relation, DataCycleCore::CollectedClassificationContent.concepts
    end

    test 'PgDictMapping check_missing and upsert_missing manage locale dictionaries' do
      assert_kind_of Array, DataCycleCore::PgDictMapping.check_missing
      assert DataCycleCore::PgDictMapping.upsert_missing
    end

    test 'Subscription.things and Subscription.users resolve related records' do
      assert_kind_of ActiveRecord::Relation, DataCycleCore::Subscription.things
      assert_kind_of ActiveRecord::Relation, DataCycleCore::Subscription.users
    end
  end
end
