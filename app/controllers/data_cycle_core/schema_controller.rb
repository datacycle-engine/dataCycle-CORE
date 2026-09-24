# frozen_string_literal: true

module DataCycleCore
  class SchemaController < ApplicationController
    include DataCycleCore::AvailableLocaleResolver

    # both actions expose the on-page language switcher (?language=)
    before_action :set_schema_language, only: [:index, :show]

    # content-type groups rendered on the index, in display order
    INDEX_CONTENT_TYPES = ['entity', 'embedded', 'container'].freeze

    # schema.org type (or template name) keyword -> Font Awesome 4 icon, matched
    # most-specific first. Drives the per-card icon on the index (see index view).
    #
    # Two things this list depends on, both easy to break:
    #
    # 1. Order decides. The first match wins, so the specific keyword has to sit
    #    above the generic one — "EventDescription" used to get the text-document
    #    icon because the /article|description|text|page/ group sat above /event/.
    # 2. Matching runs against the name split into words (see
    #    #icon_for_schema_name), and the patterns anchor on word boundaries. That
    #    way a keyword only counts as its own word: "EventDescription" is
    #    "event description" and is caught by `event`, not by a substring somewhere
    #    inside another word. Without the split, \b would break CamelCase names
    #    outright ("PostalAddress" has no boundary before "Address").
    #
    # #schema_template_icon additionally asks the template's own name before its
    # schema.org ancestor chain, so an ancestor keyword can no longer outrank the
    # template's own type.
    SCHEMA_TYPE_ICONS = [
      [/\bimage/i, 'picture-o'],
      [/\b(video|webcam)/i, 'video-camera'],
      [/\b(audio|music|sound)/i, 'music'],
      [/\b(recipe|howto)/i, 'book'],
      [/\b(pdf|digital ?document)/i, 'file-pdf-o'],
      [/\bmedia ?object/i, 'file-o'],
      [/\bweb ?page/i, 'globe'],
      [/\bweb ?site/i, 'desktop'],
      [/\bblog ?post/i, 'quote-right'],
      [/\bevent ?series/i, 'calendar-o'],
      [/\bevent/i, 'ticket'],
      [/\b(article|description|text|page)/i, 'file-text-o'],
      [/\bcreative ?work\z/i, 'file-text-o'],
      [/\b(organization|company)/i, 'building-o'],
      [/\b(place|location|geo|address)/i, 'map-marker'],
      [/\b(person|user|profile)/i, 'user'],
      [/\bservice/i, 'bell-o'],
      [/\bsafety/i, 'shield'],
      [/\bcontainer/i, 'folder-o'],
      [/\bcreative ?work/i, 'pencil']
    ].freeze
    DEFAULT_SCHEMA_ICON = 'cube'

    # Maps every non-template, non-shared descriptor :kind (FragmentReader) to dataCycle's
    # OWN property-icon type class(es). Rendered as `dc-type-icon property-icon <class>`,
    # so the glyph is resolved through dataCycle's icon system (modules/components/
    # _icons.scss) — exactly like the type icons on the start page / content grid (see
    # shared/_icon.html.erb), not a hardcoded Font Awesome glyph. Nothing here is a bespoke
    # class: they are dataCycle's real attribute-type classes (type-string, type-number,
    # type-boolean, type-datetime, type-geographic, type-classification, type-linked, …),
    # so the same glyphs also drive property icons everywhere else in the app. The
    # date/classification/linked glyphs already exist in _icons.scss; the literal ones
    # (string/number/boolean/datetime/geographic/string-url) were added there alongside
    # them. Any kind not listed here falls through to the property-icon default glyph
    # (question-circle, \f059), which _icons.scss already provides.
    SCHEMA_KIND_DC_ICONS = {
      text: 'type-string',
      url: 'type-string type-string-url',
      integer: 'type-number',
      number: 'type-number',
      boolean: 'type-boolean',
      datetime: 'type-datetime',
      date: 'type-date',
      geo: 'type-geographic',
      concept: 'type-classification',
      reference: 'type-linked'
    }.freeze

    # The drawings the dependency graph offers, in switcher order: view key =>
    # Font Awesome icon. Single source of truth — the buttons are rendered from it
    # and the same keys go into the graph payload, where the component checks each
    # against its own LAYOUTS. A key without a layout (or the other way round) is
    # reported instead of silently drawing nothing.
    GRAPH_VIEWS = { network: 'share-alt', tree: 'sitemap', radial: 'bullseye' }.freeze

    helper_method :schema_template_icon, :schema_type_icon

    def index
      @schema = Schema.load_schema_from_database
      @thing_counts = cached_thing_counts
      # overlay templates are hidden from EVERY /schema surface — the index grid,
      # the dependency view and the XLSX export (see index.xlsx.axlsx) — so the
      # surfaces stay consistent. Resolved once here and shared with the views.
      @overlay_names = overlay_template_names(@schema)
      # content-type groups drive the filter badges (Alle / Inhalte); the grid
      # itself is arranged by schema.org top-level type (see #schema_type_groups).
      # Both grouping helpers reuse the overlay names resolved once above so the
      # (non-trivial) overlay lookup is not repeated per surface.
      @schema_groups = schema_index_groups(@schema, @overlay_names)
      @schema_type_groups = schema_type_groups(@schema, @overlay_names)
      # per-schema connection table, graph + stats for the "Abhängigkeiten" view
      @dependency = Schema::DependencyGraph.cached(
        schema: @schema,
        locale: @schema_language,
        thing_counts: @thing_counts,
        overlay_names: @overlay_names
      )

      respond_to do |format|
        format.xlsx
        format.any
      end
    end

    def show
      # Consume the generated OpenAPI document (v4 truth) instead of a parallel
      # schema/key mapping — see #50201. The document is built in the requested
      # schema language so property titles switch with the language switcher.
      @template = Schema::Document.new(locale: @schema_language).template(params[:id])

      raise ActiveRecord::RecordNotFound, "Couldn't find template '#{params[:id]}'" if @template.nil?
    end

    private

    # Content count per template for the cards and the "Verwendungen" columns. A
    # full-table aggregate over things, so it is cached against the newest template
    # timestamp with a short TTL: the number is an overview figure and may lag by a
    # few minutes, which is the price for not aggregating the whole table on every
    # page view.
    #
    # These and the counts baked into the dependency snapshot can disagree by up to that
    # TTL: the snapshot's key carries the locale and the overlay names too, so the entries
    # expire on independent timers, and on a snapshot hit the counts fetched here are
    # dropped for the ones it was built with. Accepted — see DependencyGraph.cached.
    def cached_thing_counts
      Rails.cache.fetch(
        ['data_cycle_core', 'schema', 'thing_counts', DataCycleCore::ThingTemplate.maximum(:updated_at)],
        expires_in: 10.minutes
      ) { DataCycleCore::Thing.group(:template_name).count }
    end

    # Language the /schema UI + content is rendered in, driven by the on-page
    # switcher (?language=). Restricted to a configured locale, falling back to
    # the user's UI locale and then the default — mirrors the openapi viewer so
    # /schema is translatable the same way as /api/config/openapi.
    def set_schema_language
      # Only the locales /schema is translated into — the gem ships fr.yml/it.yml without a
      # `schema` branch (same narrowing as OpenApi::Translations.available_locales).
      @available_locales = I18n.available_locales.select { |locale| I18n.exists?('data_cycle_core.schema.root', locale) }
      @schema_language = resolve_available_locale(params[:language], available: @available_locales)
    end

    # Template list grouped by content_type (entity/embedded/container), each group
    # sorted by schema name. Overlay templates are hidden entirely and empty groups
    # are dropped so the view stays clean. Overlay names are resolved once in #index
    # and passed in (see #overlay_template_names).
    def schema_index_groups(schema, overlay_names)
      INDEX_CONTENT_TYPES.filter_map do |content_type|
        templates = schema.templates_with_content_type(content_type)
          .reject { |t| overlay_names.include?(t.template_name) }
          .sort_by { |t| Array.wrap(t.schema_name).first.to_s.downcase }
        next if templates.blank?

        [content_type, templates]
      end
    end

    # Grid arrangement: all shown templates grouped by their schema.org top-level
    # type (CreativeWork, Place, Event, …), so related templates sit together
    # instead of being scattered by an alphabetical flat list. Groups are ordered
    # by size (largest first, then alphabetically); within a group templates are
    # ordered by their full schema.org path, then name. Overlays stay hidden
    # (names resolved once in #index and passed in). Returns [[top_type, [templates]], ...].
    def schema_type_groups(schema, overlay_names)
      INDEX_CONTENT_TYPES
        .flat_map { |content_type| schema.templates_with_content_type(content_type) }
        .reject { |t| overlay_names.include?(t.template_name) }
        .group_by { |t| schema_top_type(t) }
        .sort_by { |type, templates| [-templates.size, type.downcase] }
        .map { |type, templates| [type, templates.sort_by { |t| schema_sort_key(t) }] }
    end

    # Top-level schema.org type of a template (first ancestor), falling back to
    # the template name when a template exposes no schema.org type.
    def schema_top_type(template)
      Array.wrap(template.schema_name).first.presence || template.template_name
    end

    # Stable within-group order: cluster by full schema.org path, then by name.
    def schema_sort_key(template)
      [Array.wrap(template.schema_name).join(' / ').downcase, template.template_name.to_s.downcase]
    end

    # Names of all templates used as overlays (referenced via an entity's overlay
    # property), so they can be excluded from the schema overview.
    #
    # Asks Feature::Overlay rather than digging DataCycleCore.features directly: the raw
    # dig returns the configured attribute_keys even when the feature is switched off
    # (`:overlay: { enabled: false }` with the keys still listed), so /schema hid overlay
    # templates on an instance that does not have overlays at all.
    def overlay_template_names(schema)
      overlay_key = DataCycleCore::Feature::Overlay.enabled? ? DataCycleCore::Feature::Overlay.primary_attribute_key : nil
      return [] if overlay_key.blank?

      schema.templates.filter_map { |t| t.overlay_template_name(overlay_key) }.uniq
    end

    # Font Awesome icon (without the `fa-` prefix) for a template: its own name
    # decides, and only when that matches nothing does the schema.org ancestor
    # chain get a say. Falls back to a neutral cube.
    def schema_template_icon(template)
      own = icon_for_schema_name(template.template_name)
      return own unless own == DEFAULT_SCHEMA_ICON

      icon_for_schema_name(Array.wrap(template.schema_name).join(' '))
    end

    # Icon class for an expected-type chip.
    #
    # A chip that links to a real dataCycle template renders dataCycle's own type
    # icon ("fa dc-type-icon thing-icon <template_name>"), driven by
    # modules/components/_icons.scss and keyed by template_name (matching
    # Thing#icon_type). So an icon newly configured for a template in _icons.scss
    # shows up here automatically, and a template without a dedicated icon falls back
    # to dataCycle's default thing glyph — no hardcoded per-type mapping to maintain.
    #
    # Property kinds (text, number, boolean, datetime, date, geo, concept, reference, …)
    # render "fa dc-type-icon property-icon <class>" via SCHEMA_KIND_DC_ICONS — the glyph
    # comes from _icons.scss, the same CSS-driven mechanism as the start page, so nothing
    # is hardcoded in Ruby. An unmapped kind renders the bare property-icon, which falls
    # back to dataCycle's own property-icon default glyph (question-circle, \f059).
    #
    # Only schema.org shared types (kind :shared, e.g. Schedule/PropertyValue) still use
    # the curated Font Awesome mapping, matched by type name via SCHEMA_TYPE_ICONS.
    def schema_type_icon(descriptor)
      return "fa dc-type-icon thing-icon #{descriptor[:template].to_s.underscore_blanks}" if descriptor[:template].present?

      return "fa fa-#{icon_for_schema_name(descriptor[:label])}" if descriptor[:kind] == :shared

      dc_icon = SCHEMA_KIND_DC_ICONS[descriptor[:kind]]
      "fa dc-type-icon property-icon #{dc_icon}".squish
    end

    # FA icon (without the `fa-` prefix) for a schema.org type / template name,
    # matched most-specific-first against SCHEMA_TYPE_ICONS; neutral cube otherwise.
    # The name is split into lower-case words first ("EventDescription" ->
    # "event description"), so the patterns can anchor on word boundaries without
    # CamelCase hiding them.
    def icon_for_schema_name(name)
      words = name.to_s.underscore.gsub(/[^[[:alnum:]]]+/, ' ').squish
      SCHEMA_TYPE_ICONS.each { |pattern, icon| return icon if words.match?(pattern) }
      DEFAULT_SCHEMA_ICON
    end
  end
end
