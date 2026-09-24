# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the verdict describe_endpoint passes on the tools of a mount
    # (Mcp::EndpointProfile) and for the distinction it rests on: what a type CAN carry (the
    # declaration from the template definition) against what the contents actually DO carry
    # (measured on the base_query, Mcp::ContentDetails).
    #
    # The result space is built per test from a Filter::Search over the contents created for it and
    # NOT from a StoredFilter over template names: the suite creates further contents in the same
    # database, so absolute numbers would depend on them (the same approach as in geo_scope_test.rb).
    class EndpointProfileTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # A selection of the tool names of both mounts that can trigger all three verdicts: a core
      # tool, two hanging off a dimension and one without a dimension.
      # list_attributes is among them because the attributes dimension counts offerable ATTRIBUTES and
      # therefore carries no share -- the only branch of the verdict that has to manage without one.
      TOOL_NAMES = ['search_contents', 'resolve_place', 'timeseries', 'suggest', 'list_attributes'].freeze

      # 'Örtlichkeit' declares a geographic property and no timeseries -- so ONE template covers both
      # cases the verdict has to separate: declared (and, depending on the content, empty or
      # occupied) against not declared at all.
      TEMPLATE_NAME = 'Örtlichkeit'

      # 'Rezept' links directly to 'Bild' under 'image' -- the only dimension whose target templates
      # come from the database (an asset property) rather than from an enumeration in the gem.
      MEDIA_TEMPLATE_NAME = 'Rezept'

      # 'Tour' carries the property 'line' through the geo_shape mixin -- the only one
      # elevation_profile hangs off.
      ELEVATION_TEMPLATE_NAME = 'Tour'

      MIN_SHARE = DataCycleCore::Mcp::EndpointProfile::MIN_DETAIL_SHARE

      # As many contents WITHOUT geodata as it takes for a single one WITH geodata to fall below
      # MIN_SHARE: 1/(FILLERS+1) lies below it, 1/FILLERS exactly on it -- so the same number covers
      # the thin case and the borderline case. Computed from the constant rather than written down as
      # a number, so a changed threshold cannot make the test silently ineffective (at 0.05 it is 20
      # contents, share 0.048 and 0.05 respectively). round rather than ceil, because 1/0.05 as a
      # float could also come out as 20.000000000000004 and ceil would then be one too high.
      SPARSE_FILLER_COUNT = (1 / MIN_SHARE).round

      before(:all) do
        @with_geo = create_place(location: RGeo::Geographic.spherical_factory(srid: 4326).point(10, 10))
        @without_geo = create_place
        @sparse_fillers = Array.new(SPARSE_FILLER_COUNT) { create_place }
        image = create_thing('Bild', 'name' => "endpoint profile test image #{SecureRandom.hex(6)}")
        @with_image = create_thing(MEDIA_TEMPLATE_NAME, 'image' => [image.id])
        @without_image = create_thing(MEDIA_TEMPLATE_NAME)
        @with_elevation = create_thing(ELEVATION_TEMPLATE_NAME, 'line' => line_string(1200))
        @without_elevation = create_thing(ELEVATION_TEMPLATE_NAME, 'line' => line_string(0))
      end

      test 'a declared and populated dimension is measured and its tool recommended' do
        profile = profile_for(@with_geo, @without_geo)

        assert_equal({ content_count: 1, share: 0.5 }, detail(profile, 'geo').slice(:content_count, :share))
        assert_equal 'recommended', status(profile, 'resolve_place')
      end

      # The actual purpose of the tool: the dimension is declared but no content carries it. Without
      # this verdict a client calls resolve_place, gets an empty response and reads it as a mistake of
      # its own -- the server's tool list looks the same in both cases.
      test 'a declared but empty dimension is reported with zero and its tool marked no_data' do
        profile = profile_for(@without_geo)
        geo = detail(profile, 'geo')

        assert_equal 0, geo[:content_count]
        assert_includes geo[:templates], TEMPLATE_NAME
        assert_equal 'no_data', status(profile, 'resolve_place')
      end

      # An occupied but too THIN dimension is not a recommendation: a single content with geodata
      # made resolve_place the recommended entry point although it contributes nothing on almost every
      # hit (measured in the 'KulinarischesErbe' endpoint: 1 of 110, share 0.009).
      #
      # But thin does NOT mean no_data either -- that is the promise that every call answers empty,
      # and it would be wrong here: for that one content the tool does answer. So two cases fall to
      # "available" that a client has to tell apart, and the difference hangs on the detail field: a
      # thin dimension names it, "hangs off no dimension" (suggest) does not.
      test 'a dimension below the minimum share is available and named by its detail' do
        profile = profile_for(@with_geo, *@sparse_fillers)

        assert_operator detail(profile, 'geo')[:share], :<, MIN_SHARE
        assert_equal ['available', 'geo'], tool_entry(profile, 'resolve_place').values_at(:status, :detail)
        assert_not tool_entry(profile, 'suggest').key?(:detail)
      end

      # share is rounded to three places (ContentDetails#measured): one content out of 2,001 stands
      # there as 0.0 although it carries the dimension. Decided on the share, the verdict would be
      # no_data -- i.e. the promise that EVERY call answers empty -- and a client would stop calling
      # the tool even for that one content. That is why no_data hangs on the absolute number. No test
      # creates 2,001 contents, so the rounded measurement is substituted instead.
      test 'a dimension whose share rounds to zero is available, not no_data' do
        profile = profile_with_details([{ detail: 'geo', content_count: 1, share: 0.0, tools: ['resolve_place'] }])

        assert_equal 'available', status(profile, 'resolve_place')
      end

      # The counter-check to the rounding: WITHOUT a content it stays no_data. Otherwise the fix would
      # have turned into a tool reported as usable on a demonstrably empty dimension.
      test 'a dimension measured as empty stays no_data even though it is declared' do
        profile = profile_with_details([{ detail: 'geo', content_count: 0, share: 0.0, tools: ['resolve_place'] }])

        assert_equal 'no_data', status(profile, 'resolve_place')
      end

      # Dimensions that count not contents but offerable trees or attributes carry no share -- a share
      # would make no sense there either (4 trees out of how many?). For them it stays at
      # present/not present, or list_facets and list_attributes would silently fall to no_data over a
      # missing share and would no longer be recommended on any endpoint.
      test 'a dimension counting structures instead of contents is recommended without a share' do
        profile = profile_for(@with_geo, *@sparse_fillers)
        attributes = detail(profile, 'attributes')

        assert_not attributes.key?(:share)
        assert_operator attributes[:filterable_attributes], :>, 0
        assert_equal 'recommended', status(profile, 'list_attributes')
      end

      # The threshold is inclusive: exactly MIN_SHARE is a recommendation. Otherwise the verdict would
      # hang on the rounding of share (three places) rather than on the threshold.
      test 'a dimension exactly at the minimum share is recommended' do
        profile = profile_for(@with_geo, *@sparse_fillers.first(SPARSE_FILLER_COUNT - 1))

        assert_in_delta MIN_SHARE, detail(profile, 'geo')[:share]
        assert_equal 'recommended', status(profile, 'resolve_place')
      end

      # Not declared means: absent from details (rather than carried as 0), so "does not exist here at
      # all" stays distinguishable from "exists but is unmaintained". The verdict on the tool has to be
      # no_data all the same and must not fall through to "available".
      test 'a dimension no template declares is absent from details and its tool still marked no_data' do
        profile = profile_for(@with_geo)

        assert_nil detail(profile, 'timeseries')
        assert_equal 'no_data', status(profile, 'timeseries')
      end

      # For the classifications the catalogue also names list_concepts, which exists only
      # instance-wide. Unfiltered, a tool would stand recommended on the endpoint mount that does not
      # appear in its tools/list at all -- the client calls it and gets "Method not found" in reply to
      # a recommendation.
      test 'a detail names only tools this mount actually serves' do
        profile = profile_for(@with_geo)

        assert_equal ['resolve_place'], detail(profile, 'geo')[:tools]
        assert_empty detail(profile, 'classifications')[:tools]
      end

      test 'a tool that hangs on no measured dimension is available, a core tool recommended' do
        profile = profile_for(@with_geo)

        assert_equal 'available', status(profile, 'suggest')
        assert_equal 'recommended', status(profile, 'search_contents')
      end

      # An empty result space makes every tool hopeless, the core tools included -- otherwise the
      # profile recommends search_contents on an endpoint without a single content.
      test 'an empty result space marks every tool no_data' do
        profile = profile_for

        assert_equal 0, profile[:content_count]
        assert_empty(profile[:tools].reject { |tool| tool[:status] == 'no_data' })
      end

      # What is judged are the tools of THIS mount, not all of the gem's: download exists only on the
      # endpoint mount, list_endpoints only instance-wide, the writing ones only under write_enabled.
      test 'the verdict covers exactly the tools of the mount' do
        assert_equal TOOL_NAMES, profile_for(@with_geo)[:tools].pluck(:tool)
      end

      test 'the endpoint block carries the stored filter identity and whether it is queryable here' do
        stored_filter = DataCycleCore::StoredFilter.create!(name: 'endpoint profile test', api: true)
        endpoint = profile_for(@with_geo, stored_filter:, queryable_here: false)[:endpoint]

        assert_equal stored_filter.id, endpoint[:id]
        assert_equal stored_filter.name, endpoint[:name]
        assert_not endpoint[:queryable_here]
      end

      # The instance-wide result space is not an endpoint and gets no invented name -- it would be
      # indistinguishable from a real endpoint name.
      test 'the endpoint block marks the instance-wide result space as a scope, not as an endpoint' do
        endpoint = profile_for(@with_geo)[:endpoint]

        assert_equal 'global', endpoint[:scope]
        assert_nil endpoint[:name]
        assert_predicate endpoint[:description], :present?
      end

      # Building the result space sets filter.language to Mcp::QUERY_LANGUAGE ('all') -- in the
      # controller on the endpoint mount (FilterConcern#build_search_query), in Mcp::ApiScope for a
      # foreign endpoint_id -- and on EXACTLY THE record that is described afterwards. Read from the
      # object, describe_endpoint therefore reported 'all' for every endpoint and contradicted
      # list_endpoints, which reads the same value from an untouched record.
      test 'the endpoint block reports the maintained language, not the query language of the result space' do
        stored_filter = DataCycleCore::StoredFilter.create!(name: 'endpoint profile language test', api: true, language: ['de'])
        base_query = DataCycleCore::Mcp::ApiScope.new(current_user: nil, stored_filter:).base_query

        assert_equal DataCycleCore::Mcp::QUERY_LANGUAGE, stored_filter.language

        profile = DataCycleCore::Mcp::EndpointProfile.new(
          stored_filter:, base_query:, tool_names: TOOL_NAMES, queryable_here: true, locale: I18n.default_locale
        ).call

        assert_equal ['de'], profile.dig(:endpoint, :language)
      end

      # Every entry names the declaring templates -- the one half of the distinction the tool rests on
      # (what a type CAN carry against what the contents DO carry). attributes was the only entry
      # without them, although the tool description promises both per dimension.
      test 'every detail entry names the templates that declare the dimension' do
        details = profile_for(@with_geo, @with_image)[:details]

        assert_predicate details, :present?

        details.each do |entry|
          assert_predicate entry[:templates], :present?, "#{entry[:detail]} names no templates"
          assert_includes entry.keys, :api_names, "#{entry[:detail]} names no api_names"
          assert_includes entry.keys, :tools, "#{entry[:detail]} names no tools"
        end
      end

      # The media dimension is the only measurement with a join and the only one whose target
      # templates come from the database (every template with an asset property) rather than from an
      # enumeration in the gem -- an instance with other media types would otherwise fall through
      # silently.
      test 'a linked asset is declared and measured as the media dimension' do
        media = detail(profile_for(@with_image, @without_image), 'media')

        assert_equal 1, media[:content_count]
        assert_in_delta 0.5, media[:share]
        assert_includes media[:templates], MEDIA_TEMPLATE_NAME
      end

      # The measurement of the elevation dimension mirrors the conditions under which
      # ElevationProfileRenderer returns a profile rather than a 404 -- two formulations of the same
      # fact in two languages (SQL here, Ruby there). If one of them drifts, describe_endpoint reports
      # contents as "carries elevation data" for which the tool then finds nothing: exactly the
      # confusion of an empty dimension with a mistake of one's own that the tool is built against.
      # Hence both are checked against the same two contents.
      test 'the elevation measurement agrees with the renderer that decides the tool response' do
        assert_equal 1, detail(profile_for(@with_elevation, @without_elevation), 'elevation')[:content_count]
        assert_predicate render_elevation_profile(@with_elevation), :present?
        assert_raises(DataCycleCore::ApiRenderer::Error::RendererError) { render_elevation_profile(@without_elevation) }
      end

      # A relation names either ONE target template or a LIST of permitted ones. Read as text, the
      # list would come out as the JSON expression `["A", "B"]`, which matches no template name -- the
      # media dimension would silently fail for exactly the relations that allow several image types.
      # Checked directly at the derivation, because no test template carries a list WITH an asset in
      # it: on a finished profile the bug would therefore not be visible here at all.
      test 'a relation declaring several target templates is read as a list, not as JSON text' do
        details = DataCycleCore::Mcp::ContentDetails.new(
          base_query: DataCycleCore::Filter::Search.new(locale: ['de']),
          stored_filter: nil,
          template_names: ['Embedded-Multiple-Templates-Entity-1'],
          content_count: 0
        )
        property = details.send(:properties).find { |p| p[:name] == 'embedded_creative_work' }

        assert_equal ['Embedded-Multiple-Templates-1', 'Embedded-Multiple-Templates-2'], property[:target_templates]
      end

      # The tool -> dimension mapping sits in Mcp::ContentDetails::TOOLS and is merely reversed by
      # EndpointProfile. A typo in it is invisible from outside: the tool would silently fall back to
      # "available", i.e. to a recommendation without backing.
      test 'every tool named in the detail catalogue exists on at least one mount' do
        known = (
          DataCycleCore::Mcp::Servers::GlobalServer::TOOLS + DataCycleCore::Mcp::Servers::SingleEndpointServer::TOOLS
        ).map(&:tool_name)

        assert_empty DataCycleCore::Mcp::EndpointProfile::TOOL_DETAILS.keys - known
        assert_empty DataCycleCore::Mcp::EndpointProfile::CORE_TOOLS - known
      end

      private

      def create_place(location: nil)
        create_thing(TEMPLATE_NAME, location.nil? ? {} : { 'location' => location })
      end

      # Z > 0 means elevation data, Z = 0 means none (ElevationProfileRenderer checks coords[2] per
      # point, the measurement ST_ZMax over the whole line -- the same statement).
      def line_string(elevation)
        factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)

        factory.line_string([factory.point(9.9, 47.2, elevation), factory.point(10.0, 47.3, elevation)])
      end

      def render_elevation_profile(content)
        DataCycleCore::ApiRenderer::ElevationProfileRenderer.new(content:).render
      end

      def create_thing(template_name, data_hash = {})
        DataCycleCore::TestPreparations.create_content(
          template_name:,
          data_hash: { 'name' => "endpoint profile test #{SecureRandom.hex(6)}" }.merge(data_hash)
        )
      end

      def profile_object(things, stored_filter: nil, queryable_here: true)
        DataCycleCore::Mcp::EndpointProfile.new(
          stored_filter:,
          base_query: DataCycleCore::Filter::Search.new(locale: ['de']).where(id: things.map(&:id)),
          tool_names: TOOL_NAMES,
          queryable_here:,
          locale: I18n.default_locale
        )
      end

      def profile_for(*things, stored_filter: nil, queryable_here: true)
        profile_object(things, stored_filter:, queryable_here:).call
      end

      def detail(profile, key)
        profile[:details].find { |entry| entry[:detail] == key }
      end

      # A profile with a substituted measurement: the content volume is real (and therefore not 0, or
      # the verdict would flip to no_data across the board), only the dimensions come from the
      # argument. For occupancies that cannot be produced with a reasonable number of test contents.
      def profile_with_details(details)
        profile = profile_object([@with_geo])
        profile.define_singleton_method(:details) { details }
        profile.call
      end

      def tool_entry(profile, tool)
        profile[:tools].find { |entry| entry[:tool] == tool }
      end

      def status(profile, tool)
        tool_entry(profile, tool)&.fetch(:status)
      end
    end
  end
end
