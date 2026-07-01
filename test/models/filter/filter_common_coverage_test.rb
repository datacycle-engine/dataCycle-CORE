# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the Filter::Common::{Classification,Geo,User} mixin modules.
  # These build Arel fragments on the Search query; calling them on a real
  # Search instance exercises the builder branches (the result is a Search, so
  # asserting it responds to :count is enough — no matching data is required).
  class FilterCommonCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '11111111-1111-1111-1111-111111111111'

    def search
      DataCycleCore::Filter::Search.new(locale: :de)
    end

    def admin_id
      DataCycleCore::User.find_by(email: 'admin@datacycle.at')&.id
    end

    # ---------- Filter::Common::Classification ----------

    test 'classification alias-id filter variants build executable queries' do
      [
        :classification_alias_ids_without_subtree_with_related,
        :not_classification_alias_ids_without_subtree_with_related,
        :classification_alias_ids_related,
        :not_classification_alias_ids_related
      ].each do |method|
        assert_equal(0, search.public_send(method, [UUID]).count)
        assert_respond_to(search.public_send(method, nil), :count) # blank guard returns self
      end
    end

    test 'classification path filters resolve aliases and build queries' do
      assert_kind_of(Integer, search.with_classification_paths(['Tags > Tag 3']).count)
      assert_kind_of(Integer, search.not_with_classification_paths(['Tags > Tag 3']).count)
      assert_respond_to(search.with_classification_paths(nil), :count) # blank guard
    end

    test 'not_with_classification_aliases_and_treename validates definition and builds' do
      assert_kind_of(Integer, search.not_with_classification_aliases_and_treename({ 'treeLabel' => 'Tags', 'aliases' => ['Tag 3'] }).count)
      assert_respond_to(search.not_with_classification_aliases_and_treename(nil), :count) # blank guard
      assert_raises(StandardError) { search.not_with_classification_aliases_and_treename({ 'aliases' => ['x'] }) }
      assert_raises(StandardError) { search.not_with_classification_aliases_and_treename({ 'treeLabel' => 'Tags' }) }
    end

    test 'deprecated classification filter methods raise' do
      [:classification_alias_ids, :not_classification_alias_ids, :with_classification_alias_ids_without_recursion].each do |method|
        assert_raises(DataCycleCore::Error::DeprecatedMethodError) { search.public_send(method, [UUID]) }
      end
    end

    test 'user_group_classifications filters by user group membership' do
      assert_kind_of(Integer, search.user_group_classifications(admin_id).count)
      assert_respond_to(search.user_group_classifications(nil), :count) # nil guard
    end

    # ---------- Filter::Common::Geo ----------

    test 'geo_filter and not_geo_filter dispatch by type and reject unknown filters' do
      assert_kind_of(Integer, search.geo_filter(['point'], 'geo_type').count)
      assert_kind_of(Integer, search.not_geo_filter(['point'], 'geo_type').count)
      assert_raises(RuntimeError) { search.geo_filter(nil, 'definitely_not_a_filter') }
      assert_raises(RuntimeError) { search.not_geo_filter(nil, 'definitely_not_a_filter') }
    end

    test 'geo_type and not_geo_type build queries per geometry type and for any' do
      assert_kind_of(Integer, search.geo_type(['point', 'line', 'polygon']).count)
      assert_kind_of(Integer, search.not_geo_type(['point', 'line', 'polygon']).count)
      assert_kind_of(Integer, search.geo_type(['any']).count)
      assert_kind_of(Integer, search.not_geo_type(['any']).count)
      assert_respond_to(search.geo_type([]), :count) # blank guard
    end

    test 'geo_radius builds a subquery from a geojson geometry' do
      # build-only (no #count) – avoids executing PostGIS on the encoded geometry
      assert_respond_to(search.geo_radius({ 'geom' => '{"type":"Point","coordinates":[11.0,46.0]}', 'distance' => '5', 'unit' => 'km' }), :count)
    end

    test 'within_shape decodes an encoded polyline line value' do
      assert_respond_to(search.within_shape({ 'line' => '_ibE_seK_seK_seK' }), :count)
    end

    # ---------- Filter::Common::User ----------

    test 'shared_with handles a user without data links' do
      assert_kind_of(Integer, search.shared_with([admin_id]).count)
      assert_respond_to(search.shared_with(nil), :count) # blank guard
    end

    test 'shared_by_collection_user_shares aggregates shared collections' do
      assert_kind_of(Integer, search.shared_by_collection_user_shares([admin_id]).count)
      assert_respond_to(search.shared_by_collection_user_shares(nil), :count) # blank guard
    end

    test 'shared_by_watch_list_shares builds an exists subquery' do
      assert_respond_to(search.shared_by_watch_list_shares([admin_id]), :count)
      assert_respond_to(search.shared_by_watch_list_shares(nil), :count) # blank guard
    end

    # ---------- Filter::Common::Union ----------

    test 'not_union_filter_ids builds an executable query for unknown collections' do
      assert_equal(0, search.not_union_filter_ids([UUID]).count)
    end

    test 'content_ids and not_content_ids resolve non-uuid ids via the slug subquery' do
      assert_equal(0, search.content_ids(['some-slug-not-a-uuid']).count)
      assert_equal(0, search.not_content_ids(['some-slug-not-a-uuid']).count)
    end
  end
end
