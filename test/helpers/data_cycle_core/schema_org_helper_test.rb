# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Tests the schema.org definition link resolution used by the /schema detail head
  # (#50201 follow-up). The @type list is ordered ancestors-first, so the link must
  # point at the most specific real schema.org type and never at a dcls:/skos:
  # pseudo-type.
  #
  # The url assertions go through #schema_org_type + #schema_org_url_for_type, which is
  # the pair shared/_schema_org_link uses — it needs the resolved type for the label as
  # well as the url, so there is no single-call wrapper to test.
  class SchemaOrgHelperTest < ActionView::TestCase
    include DataCycleCore::SchemaOrgHelper

    # Mirrors shared/_schema_org_link's two-step resolution.
    def definition_url(schema_types)
      schema_org_url_for_type(schema_org_type(schema_types))
    end

    test 'picks the most specific real schema.org type (last non-dcls entry)' do
      assert_equal 'MediaObject', schema_org_type(['CreativeWork', 'MediaObject', 'dcls:MediaObject'])
      assert_equal 'ContactPoint', schema_org_type(['Intangible', 'StructuredValue', 'ContactPoint', 'dcls:ContactPoint'])
    end

    test 'skips dcls: and skos: pseudo-types entirely' do
      assert_nil schema_org_type(['dcls:CustomThing', 'skos:Concept'])
    end

    test 'skips any namespaced (extension) type without a schema.org page' do
      # Snowpark: the most specific ancestor is the tourism-extension type alps:Snowpark,
      # which has no schema.org page — link must fall back to TouristAttraction instead of
      # producing https://schema.org/alps:Snowpark (404). See #50201 follow-up.
      assert_equal 'TouristAttraction', schema_org_type(['Place', 'TouristAttraction', 'alps:Snowpark', 'dcls:Snowpark'])
      assert_equal 'https://schema.org/TouristAttraction', definition_url(['Place', 'TouristAttraction', 'alps:Snowpark', 'dcls:Snowpark'])
      assert_nil schema_org_type(['alps:Snowpark', 'dcls:Snowpark'])
    end

    test 'skips an unprefixed type that is not in the schema.org vocabulary' do
      # These carry no namespace, so nothing in the name marks them as ours: EVChargingStation
      # and the Gtfs* types are DataCycle/GTFS classes with no schema.org page. Membership is
      # checked against the vocabulary so they fall back to their real ancestor.
      assert_equal 'Place', schema_org_type(['Place', 'EVChargingStation', 'dcls:Ladestation'])
      assert_equal 'Intangible', schema_org_type(['Intangible', 'GtfsStopTime', 'dcls:Haltezeiten'])
      assert_nil schema_org_type(['GtfsRoute'])
    end

    test 'accepts a single type and blank input' do
      assert_equal 'Place', schema_org_type('Place')
      assert_nil schema_org_type(nil)
      assert_nil schema_org_type([])
      assert_nil schema_org_type(['', nil])
    end

    test 'maps DataCycle spellings to the canonical schema.org class name' do
      # schema.org is case-sensitive: "Website"/"Webpage" 404, the real pages are
      # "WebSite"/"WebPage". See #50201 follow-up.
      assert_equal 'WebSite', schema_org_type(['CreativeWork', 'Website'])
      assert_equal 'WebPage', schema_org_type(['CreativeWork', 'Webpage'])
      assert_equal 'Organization', schema_org_type(['Organisation'])
      assert_equal 'https://schema.org/WebSite', definition_url(['CreativeWork', 'Website', 'dcls:Website'])
      assert_equal 'https://schema.org/WebPage', definition_url(['CreativeWork', 'Webpage', 'dcls:Webpage'])
    end

    test 'builds the schema.org definition url, or nil when nothing maps' do
      assert_equal 'https://schema.org/Place', definition_url(['Place', 'dcls:Place'])
      assert_nil definition_url(['dcls:Foo'])
      assert_nil definition_url(nil)
    end
  end
end
