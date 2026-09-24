# frozen_string_literal: true

module DataCycleCore
  # Resolves the schema.org definition link for a set of @type values, so the /schema
  # detail head can offer a "jump to schema.org" button "where possible" (#50201
  # follow-up), through shared/_schema_org_link. "Where possible" is decided against the
  # real vocabulary (Rdf::Terms.schema_class?), not by the shape of the name, so a
  # DataCycle-only type never produces a dead link.
  module SchemaOrgHelper
    SCHEMA_ORG_BASE_URL = 'https://schema.org/'
    # DataCycle uses a few @type spellings that differ from the canonical schema.org
    # class name (schema.org is case-sensitive, so "Website" 404s while "WebSite" is the
    # real page). Map the known ones so the link points at the existing page.
    SCHEMA_ORG_TYPE_ALIASES = {
      'Website' => 'WebSite',
      'Webpage' => 'WebPage',
      'Organisation' => 'Organization'
    }.freeze

    # The most specific real schema.org type in a list of @type values, or nil when none
    # maps to schema.org. api_schema_types is ordered ancestors-first (least specific
    # first, e.g. ["Place", "EVChargingStation", "dcls:Ladestation"]), so we walk it from
    # the back and take the first token that is a schema.org class.
    #
    # Two tokens never are: a namespaced one (containing a ':', e.g. "alps:Snowpark") is a
    # DataCycle-/extension-specific class, and an unprefixed name can still be one of ours
    # (EVChargingStation, GtfsStop). Skipping both means Ladestation links to its Place
    # ancestor rather than to a 404. Known spelling differences are mapped first, since
    # schema.org is case-sensitive ("Website" 404s, "WebSite" is the page).
    def schema_org_type(schema_types)
      Array.wrap(schema_types).flatten.compact_blank.reverse_each do |type|
        next if type.to_s.include?(':')

        canonical = SCHEMA_ORG_TYPE_ALIASES.fetch(type.to_s, type.to_s)
        return canonical if DataCycleCore::Rdf::Terms.schema_class?(canonical)
      end

      nil
    end

    # URL for an already-resolved schema.org type (see #schema_org_type), or nil.
    def schema_org_url_for_type(type)
      return if type.blank?

      "#{SCHEMA_ORG_BASE_URL}#{type}"
    end

    # Breadcrumb-style schema.org path shown on a /schema card (e.g. "CreativeWork >
    # Article"), falling back to the template name for templates without a schema.org
    # type chain. Single source of truth for both the overview and its tests.
    def schema_display_path(template)
      Array.wrap(template.schema_name).join(' > ').presence || template.template_name
    end

    # 'main' / 'embedded' / 'external' for a content_type — the group a template
    # or target type is coloured by, and at the same time the CSS modifier for its
    # dot. Delegates to the single definition (see Schema.node_group).
    def schema_node_group(content_type)
      DataCycleCore::Schema.node_group(content_type)
    end
  end
end
