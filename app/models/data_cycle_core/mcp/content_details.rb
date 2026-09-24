# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Which DETAIL DIMENSIONS a result space carries -- geodata, elevation data, schedules,
    # images/assets, time series, classifications, filterable attributes, relations -- each as two
    # values that are deliberately NOT the same thing:
    #
    #   templates/api_names  Which templates of the result space DECLARE the dimension, i.e. what a
    #                        content of that type CAN carry (from the template definitions, the
    #                        materialized view content_properties).
    #   content_count        How many contents actually DO carry it (measured on the base_query).
    #
    # Both together, because neither value alone answers the question "is this tool worthwhile
    # here". A template declares `line`, and still not a single content of the endpoint may carry
    # elevation data -- elevation_profile then answers "no elevation data" for EVERY content, which
    # a client reads as a mistake of its own and repeats, rather than as an empty dimension.
    # Conversely, a measured 0 cannot be placed without the declaration: does the dimension not
    # exist in this endpoint at all, or is it merely unmaintained? That is the same distinction
    # get_schema (what a type can carry) and list_templates (what occurs) make at the type level.
    #
    # Undeclared dimensions are absent from the response rather than carried as 0 -- the same
    # compact convention as in Tools::ListEndpoints and Tools::Base#describe_scheme.
    class ContentDetails
      # The dimensions in output order. One private method <key>_detail per entry.
      DETAILS = [:geo, :elevation, :schedule, :media, :timeseries, :classifications, :attributes, :relations].freeze

      # Which tool hangs off which dimension -- the ONLY mapping, from which Mcp::EndpointProfile
      # also builds the reverse direction (tool -> dimension). Only here and not additionally there,
      # because a tool whose dimension an endpoint does not declare at all would otherwise pass as
      # "available": a recommendation that answers empty on every call.
      #
      # Dimensions without a tool (schedule, media, relations) are in the catalogue all the same:
      # they answer "does this endpoint carry opening hours / images at all" without there being a
      # tool of their own -- get_content delivers them, search_contents filters them.
      TOOLS = {
        geo: ['resolve_place'],
        elevation: ['elevation_profile'],
        schedule: [],
        media: [],
        timeseries: ['timeseries'],
        classifications: ['list_facets', 'facet_values', 'resolve_concepts', 'list_concepts'],
        attributes: ['list_attributes'],
        relations: []
      }.freeze

      # @param base_query [DataCycleCore::Filter::Search] result space of the described endpoint
      # @param stored_filter [DataCycleCore::StoredFilter, nil] nil = the instance-wide mount
      # @param template_names [Array<String>] the templates occurring in the result space
      # @param content_count [Integer] contents in the result space, the denominator for share
      def initialize(base_query:, stored_filter:, template_names:, content_count:)
        @base_query = base_query
        @stored_filter = stored_filter
        @template_names = template_names
        @content_count = content_count
      end

      # @return [Array<Hash>] one entry per declared dimension, in DETAILS order.
      def to_a
        DETAILS.filter_map { |key| send(:"#{key}_detail") }
      end

      private

      # Geodata: every property of type geographic. Measured through the geometries table -- a
      # geographic property is stored there, NOT in thing_translations (see Mcp::GeoScope).
      def geo_detail
        detail(:geo, properties.select { |p| p[:type] == 'geographic' }) { measured(geo_sql) }
      end

      # Elevation data is a dimension of its own and not part of geo: elevation_profile needs
      # exactly the property `line` with a line geometry carrying a Z coordinate > 0
      # (ApiRenderer::ElevationProfileRenderer checks in that order and otherwise answers 404). So an
      # endpoint full of point geometries has 100% geo and 0% elevation.
      def elevation_detail
        detail(:elevation, properties.select { |p| p[:type] == 'geographic' && p[:name] == 'line' }) { measured(elevation_sql) }
      end

      # Schedules: schedule (event dates, validities) and opening_time (opening hours). Both live in
      # the schedules table -- opening_time is the same structure with a different meaning
      # (DataCycleCore::Schedule), hence one dimension and one measurement.
      def schedule_detail
        detail(:schedule, properties.select { |p| p[:type].in?(['schedule', 'opening_time']) }) { measured(schedule_sql) }
      end

      # Images/assets: relations whose TARGET template carries an asset property (ImageObject, PDF,
      # VideoObject ...). The target templates are queried rather than enumerated: which types carry
      # a file is a matter of the installed template definitions, and a literal in the gem would be a
      # silent false assumption on every differently configured instance.
      def media_detail
        detail(:media, properties.select { |p| p[:target_templates].intersect?(asset_templates) }) { measured(media_sql) }
      end

      def timeseries_detail
        detail(:timeseries, properties.select { |p| p[:type] == 'timeseries' }) { measured(timeseries_sql) }
      end

      # Classifications are NOT measured as a share of contents: almost every content carries some
      # assignment (content pool, output channel, licence), so the number would always be ~100% and
      # say nothing. The load-bearing value is how many trees the endpoint offers at all -- curated
      # or derived from the inventory, the same derivation as in list_facets (Mcp::EndpointFacets).
      # Which trees those are and how many contents hang off each is what list_facets says; here it
      # only says whether the call is worthwhile.
      def classification_schemes
        @classification_schemes ||= DataCycleCore::Mcp::EndpointFacets
          .scope({ stored_filter: @stored_filter, base_query: @base_query })
          .count
      end

      def classifications_detail
        detail(:classifications, properties.select { |p| p[:type] == 'classification' }) { { concept_schemes: classification_schemes } }
      end

      # Filterable attributes through Mcp::AttributeFilter rather than through a selection of
      # properties of our own: which types search_contents' attributes filter can really serve is
      # decided by FILTERABLE_TYPES there -- rebuilt here, the list would be a duplicate that at the
      # next extension names attributes no filter accepts.
      def filterable_attributes
        @filterable_attributes ||= DataCycleCore::Mcp::AttributeFilter.new.available(@template_names)
      end

      # The only dimension not built through #detail: the api_names come from Mcp::AttributeFilter
      # (see above) and not from the declaring properties, and the entry has to stand even when no
      # property can be found for them. The declaring templates are named all the same -- otherwise
      # attributes would be the only entry without `templates` although the tool description promises
      # both values per dimension, and a client could not relate an attribute filter to the types
      # that carry the attribute at all.
      #
      # The api_names are counted DEDUPLICATED: list_attributes carries a name twice when two
      # templates carry it with a different property_type (the case once in this instance). Filtering
      # goes through the name, though -- a list with the same entry twice and a number that counts it
      # twice are both uninterpretable to a client.
      def attributes_detail
        api_names = filterable_attributes.pluck(:attribute).uniq.sort
        return nil if api_names.empty?

        {
          detail: 'attributes',
          filterable_attributes: api_names.size,
          api_names:,
          templates: properties.select { |p| p[:api_name].in?(api_names) }.pluck(:template).uniq.sort,
          tools: TOOLS.fetch(:attributes)
        }
      end

      # Relations (linked/embedded) in total -- the dimension behind the nested values in
      # get_content: organizers, associated places, description blocks.
      def relations_detail
        detail(:relations, properties.select { |p| p[:type].in?(['linked', 'embedded']) }) { measured(relations_sql) }
      end

      # One entry, provided the dimension is declared at all. templates/api_names come from the
      # declaring properties, the measurement from the block.
      def detail(key, declaring)
        return nil if declaring.empty?

        {
          detail: key.to_s,
          **yield,
          api_names: declaring.pluck(:api_name).compact.uniq.sort,
          templates: declaring.pluck(:template).uniq.sort,
          tools: TOOLS.fetch(key)
        }
      end

      # share in addition to the absolute number: 2,500 contents with geodata are a promise in an
      # endpoint with 2,508 contents and a footnote in one with 260,000 -- and that is exactly how
      # the endpoints of one instance differ. The denominator is the endpoint's content volume, not
      # that of the declaring templates: the question is how often an arbitrary hit carries this
      # detail.
      def measured(condition)
        count = @base_query.query.where(condition).count

        { content_count: count, share: @content_count.positive? ? (count.to_f / @content_count).round(3) : 0.0 }
      end

      def geo_sql
        'EXISTS (SELECT 1 FROM geometries WHERE geometries.thing_id = things.id)'
      end

      # is_primary/relation/GeometryType/ST_ZMax mirror the four conditions under which
      # ElevationProfileRenderer returns a profile -- a looser measurement here would mean the tool
      # still answers 404 for a content reported as "present".
      def elevation_sql
        <<~SQL.squish
          EXISTS (
            SELECT 1 FROM geometries
            WHERE geometries.thing_id = things.id
              AND geometries.relation = 'line'
              AND geometries.is_primary
              AND GeometryType(geometries.geom) IN ('LINESTRING', 'MULTILINESTRING')
              AND ST_ZMax(geometries.geom) > 0
          )
        SQL
      end

      def schedule_sql
        'EXISTS (SELECT 1 FROM schedules WHERE schedules.thing_id = things.id)'
      end

      def timeseries_sql
        'EXISTS (SELECT 1 FROM timeseries WHERE timeseries.thing_id = things.id)'
      end

      def relations_sql
        'EXISTS (SELECT 1 FROM content_contents WHERE content_contents.content_a_id = things.id)'
      end

      # DIRECT relations only, matching the declaring properties: the images of an embedded
      # description block hang off that block and not off the content itself.
      def media_sql
        DataCycleCore::Thing.sanitize_sql_array(
          [
            <<~SQL.squish,
              EXISTS (
                SELECT 1 FROM content_contents
                JOIN things assets ON assets.id = content_contents.content_b_id
                WHERE content_contents.content_a_id = things.id AND assets.template_name IN (?)
              )
            SQL
            asset_templates
          ]
        )
      end

      def asset_templates
        @asset_templates ||= DataCycleCore::ContentProperties.where(property_type: 'asset').distinct.pluck(:template_name)
      end

      # The properties of every template occurring in the result space, ONE query for all dimensions.
      #
      # Nested paths (address.postalCode, additionalInformation.image) drop out -- the same boundary
      # as in Mcp::AttributeFilter#available and Mcp::WritableAttributes#api_names. For the
      # declaration it is additionally a matter of honesty here: the measurements count geometries,
      # schedules and relations ON THE CONTENT, whereas an image under an embedded description block
      # hangs off that block. Declaration and measurement would otherwise mean two different things,
      # and the coverage would look bad for no reason.
      #
      # property_definition is not loaded whole, only the single field needed: across all templates
      # of an unfiltered endpoint that would otherwise be several thousand JSON documents for one
      # value per row.
      #
      # `->` and not `->>`: a relation names either ONE target template or a LIST of permitted ones
      # (measured: 7 of 959, e.g. Story#content_block -> ["ContentBlock", "ImageGallery"]). Read as
      # text, those would come out as the JSON expression `["ContentBlock", ...]`, which matches no
      # template name -- the media dimension would silently fail for exactly the relations that allow
      # several image types, and an endpoint full of images would look as though it carried none.
      # jsonb comes back as a Ruby value (String, Array or nil), and Array.wrap brings all three
      # forms to the same one.
      def properties
        @properties ||= DataCycleCore::ContentProperties
          .where(template_name: @template_names)
          .pluck(:template_name, :property_name, :api_name, :property_type, Arel.sql("property_definition->'template_name'"))
          .reject { |_template, name, _api_name, _type, _targets| name.include?('.') }
          .map { |template, name, api_name, type, targets| { template:, name:, api_name:, type:, target_templates: Array.wrap(targets) } }
      end
    end
  end
end
