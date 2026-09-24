# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Covers the backend HTML schema overview (DataCycleCore::SchemaController,
  # routes.rb `get '/schema'` + `/schema/:id`) — this is "Emily"'s package:
  # the /schema index (grouped, searchable, filterable, thing_count) and the
  # XLSX export on api_name. NOT the JSON Api::Config::SchemaController.
  #
  # Every expectation is derived at runtime from DataCycleCore::Schema /
  # ThingTemplate / the database — nothing about the concrete template set,
  # counts or api_names is hard-coded, so the suite tracks the live config.
  class SchemaControllerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    # use the same resolution the view uses, so the test never drifts from the helper
    include DataCycleCore::SchemaOrgHelper

    before(:all) do
      @routes = Engine.routes
      @current_user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      @schema = DataCycleCore::Schema.load_schema_from_database
    end

    # ---- shared derivations (single source: the domain, not the controller) --

    # [[content_type, [templates]], ...] in the controller's display order,
    # empty groups dropped and overlay templates hidden — mirrors the presenter
    # contract Emily ships. The embedded group is present here (its cards render
    # in the grid), but it belongs to the separate embedded-schema tab, not to
    # the main schema's content-type filter (see #main_groups / #embedded_templates).
    def expected_groups
      overlays = overlay_template_names

      DataCycleCore::SchemaController::INDEX_CONTENT_TYPES.filter_map do |content_type|
        templates = @schema.templates_with_content_type(content_type)
          .reject { |t| overlays.include?(t.template_name) }
        next if templates.blank?

        [content_type, templates]
      end
    end

    # Names of all templates used as overlays (referenced via an entity's overlay
    # property); these are hidden from the overview entirely. Resolved through
    # Feature::Overlay exactly as SchemaController#overlay_template_names does, so the
    # expectation cannot drift from the controller.
    def overlay_template_names
      overlay_key = DataCycleCore::Feature::Overlay.enabled? ? DataCycleCore::Feature::Overlay.primary_attribute_key : nil
      return [] if overlay_key.blank?

      @schema.templates.filter_map { |t| t.overlay_template_name(overlay_key) }.uniq
    end

    # The two schemas the overview splits into. The main-schema groups
    # (entity + container) drive the "Hauptschema" toggle; the embedded group
    # drives the "Embedded-Schema" toggle. Overlays are already excluded upstream.
    def main_groups
      expected_groups.reject { |group| group.first == 'embedded' }
    end

    def embedded_templates
      (expected_groups.find { |group| group.first == 'embedded' } || [nil, []]).last
    end

    def main_total
      main_groups.sum { |_, templates| templates.size }
    end

    # [[property_key, target_template_name], ...] for a template's embedded
    # properties — mirrors SchemaController#embedded_edges, derived from the raw
    # schema so the dependency-view test tracks the live config.
    def embedded_edges_for(thing_template)
      (thing_template.schema['properties'] || {}).filter_map do |key, d|
        next unless d['type'] == 'embedded'

        [key, d['template_name']] if d['template_name'].present?
      end
    end

    # The non-embedded templates that embed at least one template — the roots of
    # the dependency tree the "Abhängigkeiten" view renders.
    def dependency_roots
      overlays = overlay_template_names
      DataCycleCore::ThingTemplate.all
        .reject { |t| t.schema['content_type'] == 'embedded' || overlays.include?(t.template_name) }
        .select { |t| embedded_edges_for(t).any? }
    end

    # The rows the "Abhängigkeiten" tab actually lists: every template with at
    # least one connection property (reference/shared/geo, not just embedded) —
    # mirrors DataCycleCore::Schema::DependencyGraph#rows (single source of truth).
    def dependency_rows
      DataCycleCore::Schema::DependencyGraph.new(
        schema: @schema,
        locale: @schema_language || I18n.default_locale,
        thing_counts: DataCycleCore::Thing.group(:template_name).count,
        overlay_names: overlay_template_names
      ).rows
    end

    def display_name_for(template)
      schema_display_path(template)
    end

    def db_thing_count(template)
      DataCycleCore::Thing.where(template_name: template.template_name).count
    end

    # Top-level schema.org type the grid groups a template under.
    def schema_top_type(template)
      Array.wrap(template.schema_name).first.presence || template.template_name
    end

    # The grid arrangement the presenter ships: all shown templates grouped by
    # schema.org top-level type, groups ordered by size (largest first, then
    # alphabetically), templates within a group by full path then name. Mirrors
    # SchemaController#schema_type_groups. Returns [[top_type, [templates]], ...].
    def expected_type_groups
      overlays = overlay_template_names

      DataCycleCore::SchemaController::INDEX_CONTENT_TYPES
        .flat_map { |content_type| @schema.templates_with_content_type(content_type) }
        .reject { |t| overlays.include?(t.template_name) }
        .group_by { |t| schema_top_type(t) }
        .sort_by { |type, templates| [-templates.size, type.downcase] }
        .map { |type, templates| [type, templates.sort_by { |t| [Array.wrap(t.schema_name).join(' / ').downcase, t.template_name.to_s.downcase] }] }
    end

    # First [TemplatePresenter, PropertyPresenter] whose property matches the block,
    # discovered at runtime from the same OpenAPI document the detail view consumes —
    # so these tests track the live config instead of a fixed template/property.
    def first_detail_property_where(&block)
      document = DataCycleCore::Schema::Document.new(locale: I18n.default_locale)
      match = nil
      DataCycleCore::ThingTemplate.all.find do |thing_template|
        template = document.template(thing_template.template_name)
        next false if template.nil?

        property = template.properties.find(&block)
        next false if property.nil?

        match = [template, property]
      end
      match || [nil, nil]
    end

    # -------------------- anonymous is redirected to the login --------------------
    test 'GET /schema without a session redirects to the sign-in page' do
      get schema_path

      assert_response :redirect
      assert_match(/sign_in/, response.location)
    end

    test 'GET /schema/:id without a session redirects to the sign-in page' do
      get schema_details_path(id: 'some_template_name')

      assert_response :redirect
      assert_match(/sign_in/, response.location)
    end

    # /schema's components and ~2.5k lines of SCSS ship as entrypoints/schema.js instead
    # of in the application bundle, so they cost nothing on every other backend page.
    # Both pages have to request it, or the filters and the dependency graph stay dead.
    test 'both schema pages load the schema entrypoint' do
      sign_in(@current_user)

      get schema_path

      assert_response :success
      assert_match(%r{entrypoints/schema|schema-[-\w]+\.js}, response.body, '/schema must request its entrypoint')

      get schema_details_path(id: DataCycleCore::ThingTemplate.first.template_name)

      assert_response :success
      assert_match(%r{entrypoints/schema|schema-[-\w]+\.js}, response.body, '/schema/:id must request its entrypoint')
    ensure
      sign_out(@current_user)
    end

    # -------------------- signed-in users see the page --------------------
    test 'GET /schema with a signed-in session renders the searchable, filterable overview' do
      sign_in(@current_user)

      get schema_path

      assert_response :success
      assert_select 'main.schema-index'
      assert_select 'button[data-schema-part="main"]' # "Hauptschema" schema toggle
      assert_select 'button[data-schema-with-content]' # "nur mit Inhalten" toggle
      assert_select '.schema-groups' # grid container
      assert_select '.schema-group', minimum: 1                       # cards grouped by schema.org type
      assert_select '.schema-card[data-type]', minimum: 1             # each card tagged with its content type
      assert_select '.schema-card__icon .fa', minimum: 1             # per-type Font Awesome icon
      assert_select '.schema-card__count', minimum: 1                # thing_count per template
      assert_select 'input[data-schema-search]'                      # client-side filter
    ensure
      sign_out(@current_user)
    end

    # ---- card layout: the vertical tile (icon+name header → path → footer) ----
    # The redesign stacks the card: an icon+name header, the schema.org path, then
    # a footer holding the count + a chevron pinned to the bottom. This asserts the
    # DOM the CSS depends on so the tile can't silently regress to the former
    # single-row card: the header/footer wrappers must exist, the count must sit
    # INSIDE the footer, and the old `.schema-card__body` wrapper must be gone.
    # Structure is checked on a real template's card; the name/path text is derived
    # from the domain (never hard-coded), matching the rest of this suite.
    test 'GET /schema renders each card as an icon+name header, a path, and a footer holding the count and chevron' do
      template = expected_type_groups.flat_map(&:last).first
      skip 'no templates in the schema overview for this instance' if template.nil?

      sign_in(@current_user)
      get schema_path

      assert_response :success

      card = css_select('li.schema-card').find do |li|
        li.at_css('a.schema-card__link')&.[]('href') == "/schema/#{template.template_name}"
      end

      assert_not_nil card, "expected a card linking to /schema/#{template.template_name}"

      link = card.at_css('a.schema-card__link')

      # header row: icon + name together (the name no longer sits in a separate body)
      header = link.at_css('.schema-card__header')

      assert_not_nil header, 'card must wrap the icon and name in a .schema-card__header'
      assert header.at_css('.schema-card__icon .fa'), 'the icon must live inside the header'
      name = header.at_css('.schema-card__name')

      assert_not_nil name, 'the name must live inside the header'
      assert_equal template.template_name.to_s, name.text.strip

      # schema.org path sits between header and footer as its own element
      key = link.at_css('.schema-card__key')

      assert_not_nil key, 'card must render the schema.org path (.schema-card__key)'
      assert_equal display_name_for(template), key.text.strip

      # footer: count + chevron (pinned to the bottom by the CSS)
      footer = link.at_css('.schema-card__footer')

      assert_not_nil footer, 'card must have a .schema-card__footer'
      assert footer.at_css('.schema-card__count'), 'the count must live inside the footer'
      assert footer.at_css('.schema-card__chevron'), 'the footer must render a chevron affordance'

      # the former single-row wrapper is gone
      assert_nil link.at_css('.schema-card__body'), 'the old .schema-card__body wrapper must be removed'

      sign_out(@current_user)
    end

    # ---- sort control lives on the overview (index), never on the detail page ---
    # Counterpart to "GET /schema/:id renders no sort control": the dropdown that
    # reorders the cards within each schema.org-type group belongs on /schema. Its
    # option values are the JS sort contract — each has to map to a SORTS entry in
    # schema/index_filter.js, so markup and component cannot
    # drift apart. The component's own behaviour is covered by
    # test/javascript/schema_index_filter_test.mjs; only this pairing needs the
    # rendered page, because the options come from the view and its locale files.
    SCHEMA_INDEX_FILTER_JS = DataCycleCore::Engine.root.join('app/assets/javascripts/schema/index_filter.js')

    test 'GET /schema renders the sort control with every option the component handles' do
      sign_in(@current_user)

      get schema_path

      assert_response :success
      assert_select '.schema-filter .schema-sort'                     # wrapper sits in the filter toolbar
      assert_select 'select[data-schema-sort]'                        # the dropdown itself

      sorts = SCHEMA_INDEX_FILTER_JS.read[/export const SORTS = \{(.*?)\n\};/m, 1].to_s
      component_sort_keys = sorts.scan(/(\w+):\s*\{\s*key:/).flatten.sort
      option_values = css_select('select[data-schema-sort] option').pluck('value').sort

      assert_not_empty component_sort_keys, 'expected the component to define SORTS entries'
      # every option maps to a SORTS entry and vice versa — no unhandled option, no
      # dead SORTS key.
      assert_equal component_sort_keys, option_values,
                   'the dropdown options and the component SORTS keys must match exactly'
    ensure
      sign_out(@current_user)
    end

    # The client-side sort reads data-sort-* off each card; assert they carry the
    # domain-derived values (not just that the attributes exist), so sorting by
    # heading/type/count actually orders by the right thing. All expectations come
    # from ThingTemplate / the DB via the shared helpers — nothing hard-coded.
    # (skip guard runs before sign_in, so no ensure/sign_out is needed on skip —
    # mirrors the detail-page tests below.)
    test 'GET /schema sets each card sort attribute to its domain-derived value' do
      template = expected_type_groups.flat_map(&:last).first
      skip 'no templates in the schema overview for this instance' if template.nil?

      sign_in(@current_user)
      get schema_path

      assert_response :success

      card = css_select('li.schema-card').find do |li|
        link = li.at_css('a.schema-card__link')
        link && link['href'].to_s == "/schema/#{template.template_name}"
      end

      assert_not_nil card, "expected a card linking to /schema/#{template.template_name}"
      assert_equal template.template_name.to_s.downcase, card['data-sort-name']
      assert_equal display_name_for(template).downcase, card['data-sort-path']
      assert_equal db_thing_count(template).to_s, card['data-sort-count']

      sign_out(@current_user)
    end

    # -------------------- brand logo is config-driven, not hard-coded --------------------
    # /schema + /schema/:id drop the app nav and open on a brand strip that renders
    # the instance logo through the shared `application/_logo` partial (mirrors
    # /api/config/openapi). Nothing may hard-code a logo file: the image must follow
    # DataCycleCore.logo, and — since the test env runs without a Vite dev server,
    # like a deployment — the src must still resolve through the manifest.
    test 'GET /schema renders the brand strip logo from the DataCycleCore.logo config' do
      sign_in(@current_user)

      get schema_path

      assert_response :success
      assert_select '.schema-brand a.schema-brand-link'                    # brand strip present
      assert_select '.schema-brand .logo img.hide-for-print[alt=?]',       # alt derived from config
                    DataCycleCore.logo['alt_text']
      # src resolves from logo['normal']; the basename survives fingerprinting, and
      # deriving the expectation from the config (not a literal) keeps this honest.
      normal_base = File.basename(DataCycleCore.logo['normal'].to_s, '.*')
      assert_select '.schema-brand .logo img.hide-for-print' do |imgs|
        assert_includes imgs.first['src'].to_s, normal_base,
                        "brand logo src must derive from DataCycleCore.logo['normal'] and resolve (deployment path)"
      end
    ensure
      sign_out(@current_user)
    end

    test 'GET /schema/:id renders the same config-driven brand strip logo' do
      sign_in(@current_user)
      template = DataCycleCore::ThingTemplate.first

      get schema_details_path(id: template.template_name)

      assert_response :success
      assert_select '.schema-brand a.schema-brand-link'
      assert_select '.schema-brand .logo img.hide-for-print[alt=?]', DataCycleCore.logo['alt_text']
    ensure
      sign_out(@current_user)
    end

    test 'the brand logo follows the runtime DataCycleCore.logo config (proves it is not hard-coded)' do
      sign_in(@current_user)
      original_logo = DataCycleCore.logo
      DataCycleCore.logo = original_logo.merge('alt_text' => 'CONFIG-DRIVEN-BRAND-4711')

      get schema_path

      assert_response :success
      # if the logo were hard-coded, the alt would not track the changed config
      assert_select ".schema-brand .logo img[alt='CONFIG-DRIVEN-BRAND-4711']"
    ensure
      DataCycleCore.logo = original_logo if original_logo
      sign_out(@current_user)
    end

    # -------------------- detail page renders from the OpenAPI document (#50201) --------------------
    test 'GET /schema/:id renders the detail page with the APIv4 keys' do
      sign_in(@current_user)
      template = DataCycleCore::ThingTemplate.first
      component = DataCycleCore::OpenApi::DocumentBuilder.new(locale: I18n.default_locale).call
        .dig('components', 'schemas', DataCycleCore::OpenApi::EntityBuilder.component_name(template.template_name))

      get schema_details_path(id: template.template_name)

      assert_response :success
      # the delivered api_name keys (not internal labels) are shown
      component['properties'].each_key do |api_name|
        assert_includes response.body, api_name, "expected api_name #{api_name} in the detail page"
      end
    ensure
      sign_out(@current_user)
    end

    # #50201 (review 2.3): the ticket asks for the schema.org types AND the content
    # count per template. The detail head carries the same figure the index card shows
    # — taken from the presenter (thing_count), derived here from the DB (never faked)
    # so the two /schema surfaces can't drift. It sits in the head meta row, beside the
    # schema.org link, distinct from the property count on the filter row (which counts
    # attributes, not contents).
    test 'GET /schema/:id shows the template thing_count in the head meta row, consistent with the database' do
      # prefer the template with the most contents so the assertion exercises a real
      # (non-delimited) figure where the instance has data; falls back to any template.
      # (skip guard runs before sign_in, so no ensure/sign_out is needed on skip.)
      template = DataCycleCore::ThingTemplate.all.max_by { |t| db_thing_count(t) } || DataCycleCore::ThingTemplate.first
      skip 'no templates in this instance' if template.nil?

      sign_in(@current_user)
      get schema_details_path(id: template.template_name)

      assert_response :success
      # the count sits in the head meta row (beside the schema.org link), NOT on the
      # property/filter row further down (which counts attributes, not contents).
      count_el = css_select('.schema-detail__meta .schema-detail__count').first

      assert count_el, 'the detail head must render the content count (.schema-detail__count) in the meta row'
      assert_empty css_select('.schema-filter .schema-detail__count'),
                   'the content count must not leak onto the property/filter row'
      rendered = count_el.text.gsub(/\D/, '').to_i

      assert_equal db_thing_count(template), rendered, "detail thing_count for #{template.template_name}"

      sign_out(@current_user)
    end

    # #50201 follow-up: the detail head shows the SAME object icon the /schema index
    # card assigns to this template (schema_template_icon) — one icon mapping, so the
    # two surfaces cannot drift. It lives inside the H1 so it scales with the responsive
    # title font-size.
    test 'GET /schema/:id renders the object icon inside the title, matching the index icon (single mapping)' do
      template = DataCycleCore::ThingTemplate.first
      skip 'no templates in this instance' if template.nil?

      sign_in(@current_user)
      get schema_details_path(id: template.template_name)

      assert_response :success
      icon = css_select('.schema-detail__title-row h1 i.schema-detail__icon').first

      assert icon, 'the detail title must render the object icon (.schema-detail__icon) inside the H1'
      # derived from the very presenter + helper the controller/view use — proving the
      # head reuses schema_template_icon rather than mapping the icon a second time.
      presenter = DataCycleCore::Schema::Document.new(locale: I18n.default_locale).template(template.template_name)
      expected_icon = DataCycleCore::SchemaController.new.send(:schema_template_icon, presenter)

      assert_includes icon['class'].split, "fa-#{expected_icon}", 'the head icon must be schema_template_icon(template)'

      sign_out(@current_user)
    end

    # An embedded template reads in the violet accent on the detail head, mirroring the
    # embedded cards on the index — driven by the --embedded modifier the view emits
    # only when the template's content_type is 'embedded' (no colour lives in the view).
    test 'GET /schema/:id gives an embedded template the violet --embedded icon modifier' do
      template = DataCycleCore::ThingTemplate.where(content_type: 'embedded').first
      skip 'no embedded template in this instance' if template.nil?

      sign_in(@current_user)
      get schema_details_path(id: template.template_name)

      assert_response :success
      assert css_select('.schema-detail__title-row h1 i.schema-detail__icon.schema-detail__icon--embedded').first,
             'an embedded template must carry the --embedded icon modifier (violet accent), like its index card'

      sign_out(@current_user)
    end

    # #50201 follow-up: the per-property cardinality marker was removed from the detail
    # rows (it now only lives on the dependency view). A :many property must therefore
    # render no .schema-card__cardinality span on the detail page anymore.
    test 'GET /schema/:id renders no per-property cardinality marker on the detail rows' do
      presenter, = first_detail_property_where { |property| property.cardinality == :many }
      skip 'no multi-valued property in this instance' if presenter.nil?

      sign_in(@current_user)
      get schema_details_path(id: presenter.template_name)

      assert_response :success
      assert_operator css_select('.schema-card').size, :>, 0, 'sanity: the detail page rendered property cards'
      assert_empty css_select('.schema-card__cardinality'),
                   'the cardinality marker was removed from the detail property rows (#50201 follow-up)'

      sign_out(@current_user)
    end

    test 'GET /schema/:id links the title to the schema.org definition where possible' do
      sign_in(@current_user)
      # a template whose type actually maps to schema.org (#50201 follow-up)
      template = DataCycleCore::ThingTemplate.find_by(template_name: 'Place') || DataCycleCore::ThingTemplate.first

      get schema_details_path(id: template.template_name)

      assert_response :success
      # the schema.org button sits in the detail head, only when a real schema.org type exists
      expected_url = schema_org_url_for_type(schema_org_type(template.api_schema_types))
      assert_select '.schema-detail__head a.schema-org-link[href=?]', expected_url if expected_url.present?
    ensure
      sign_out(@current_user)
    end

    # -------------------- language switcher (mirrors /api/config/openapi) --------------------
    # Also covers the light/dark toggle's localized labels (behaviour:
    # schema/theme_toggle.js) via assert_theme_toggle_localized,
    # piggy-backing on the requests this test already makes for each locale
    # rather than issuing dedicated ones.
    test 'GET /schema offers a DE/EN language switcher and renders the labels in the requested language' do
      sign_in(@current_user)

      get schema_path(language: :en)

      assert_response :success
      assert_select 'nav.schema-locales a.schema-locale', minimum: 2
      assert_select 'a.schema-locale.is-active', text: 'EN'
      assert_select 'input[data-schema-search][placeholder=?]', I18n.t('data_cycle_core.schema.index.search_placeholder', locale: :en)
      assert_theme_toggle_localized(:en)

      get schema_path(language: :de)

      assert_response :success
      assert_select 'a.schema-locale.is-active', text: 'DE'
      assert_select 'input[data-schema-search][placeholder=?]', I18n.t('data_cycle_core.schema.index.search_placeholder', locale: :de)
      assert_theme_toggle_localized(:de)
    ensure
      sign_out(@current_user)
    end

    test 'GET /schema/:id renders in the requested language and the switcher stays on the same template' do
      sign_in(@current_user)
      template = DataCycleCore::ThingTemplate.first

      get schema_details_path(id: template.template_name, language: :en)

      assert_response :success
      assert_select 'a.schema-locale.is-active', text: 'EN'
      # each switcher link points at the SAME template, only swapping the language
      assert_select 'nav.schema-locales a.schema-locale[href=?]', schema_details_path(template.template_name, language: :de)
      assert_theme_toggle_localized(:en)
      en_body = response.body

      # the page must actually respond to the language (labels + localized content),
      # not just echo the switcher — the DE render differs from the EN render
      get schema_details_path(id: template.template_name, language: :de)

      assert_response :success
      assert_not_equal en_body, response.body, 'the detail page must render differently per language'
      assert_theme_toggle_localized(:de)
    ensure
      sign_out(@current_user)
    end

    test 'GET /schema with an unsupported language falls back without error' do
      sign_in(@current_user)

      get schema_path(language: :xx)

      assert_response :success
      assert_select 'main.schema-index'
    ensure
      sign_out(@current_user)
    end

    test 'GET /schema/:id renders the filter header (search, facet chips, per-card facets)' do
      sign_in(@current_user)
      template = DataCycleCore::ThingTemplate.first

      get schema_details_path(id: template.template_name)

      assert_response :success
      assert_select 'input.schema-filter__input' # live title search
      assert_select 'button.schema-chip[data-schema-filter="all"]' # the always-present "Alle" chip
      assert_select 'span.schema-filter__count-visible' # live count target
      # every card carries the data-driven facets + search haystack the JS filters on
      assert_select 'li.schema-card[data-schema-categories][data-schema-search]', minimum: 1
    ensure
      sign_out(@current_user)
    end

    test 'GET /schema/:id with an unknown template returns 404' do
      sign_in(@current_user)

      get schema_details_path(id: 'this-template-does-not-exist')

      assert_response :not_found
    ensure
      sign_out(@current_user)
    end

    # #50201 AK: embedded/linked properties are navigable to their target template.
    # The detail view is link-based (recursion is structurally impossible), so we
    # assert the rendered anchor points at the target's /schema/:id page. The pair
    # (template, target) is discovered at runtime from the same OpenAPI document the
    # view consumes, so the test tracks the live config instead of a fixed template.
    test 'GET /schema/:id links an embedded/linked property to its target template detail page' do
      document = DataCycleCore::Schema::Document.new(locale: I18n.default_locale)

      presenter = nil
      target = nil
      DataCycleCore::ThingTemplate.all.find do |thing_template|
        template = document.template(thing_template.template_name)
        next false if template.nil?

        property = template.properties.find { |p| p.target_templates.present? }
        next false if property.nil?

        presenter = template
        target = property.target_templates.first
        true
      end

      skip 'no template links/embeds another routable template in this instance' if presenter.nil?

      sign_in(@current_user)
      get schema_details_path(id: presenter.template_name)

      assert_response :success
      assert_select 'a[href=?]', schema_details_path(id: target), minimum: 1

      sign_out(@current_user)
    end

    # #50201: an attribute whose value is an embedded content is shown as a single
    # top-level row marked by a violet key (schema-card__key--embedded); the embedded
    # content's own attributes are NOT expanded inline. The (template, embedded property)
    # pair is discovered at runtime from the same OpenAPI document the view consumes.
    test 'GET /schema/:id marks an embedded attribute with a violet key and does not expand its children' do
      presenter, property = first_detail_property_where { |p| p.flags[:embedded] }
      skip 'no template exposes an embedded attribute in this instance' if presenter.nil?

      sign_in(@current_user)
      get schema_details_path(id: presenter.template_name)

      assert_response :success
      # the embedded attribute itself renders with a violet-marked key …
      assert_select 'code.schema-card__key.schema-card__key--embedded', text: property.api_name, minimum: 1
      # … and its embedded content's attributes are NOT expanded as extra rows: the
      #    list shows exactly one card per top-level property, and the old inline
      #    origin marker (a ↳ / fa-level-down link) is gone. (`schema-tag--embedded`
      #    itself now legitimately styles the embedded property's own type chip, so we
      #    assert on the marker's unique icon instead of the class alone.)
      assert_select 'ol.schema-list > li.schema-card', count: presenter.properties.size
      assert_select 'a.schema-tag--embedded i.fa-level-down', false, 'embedded children must no longer be expanded as origin-marked rows'
      # … and the header offers a dedicated "Embedded" filter chip (styled violet in
      #    _detail.scss, matching the index' embedded toggle) for the embedded facet.
      assert_select 'button.schema-chip[data-schema-filter="embedded"]', minimum: 1

      sign_out(@current_user)
    end

    # ---- #50201 follow-up: shared app tooltip instead of native title ---------
    test 'GET /schema/:id uses the shared app tooltip (data-dc-tooltip), not a native title, on the back button' do
      sign_in(@current_user)
      get schema_details_path(id: DataCycleCore::ThingTemplate.first.template_name)

      assert_response :success
      assert_select 'a.schema-detail__back[data-dc-tooltip]'
      assert_select 'a.schema-detail__back[title]', false, 'back button must not fall back to a native title tooltip'
    ensure
      sign_out(@current_user)
    end

    # ---- #50201 follow-up: sorting removed, presenter order kept --------------
    test 'GET /schema/:id renders no sort control and drops the sort-only card data attributes' do
      sign_in(@current_user)
      get schema_details_path(id: DataCycleCore::ThingTemplate.first.template_name)

      assert_response :success
      assert_select 'select[data-schema-sort]', false, 'the sort dropdown was removed'
      assert_select '.schema-sort', false, 'the sort control wrapper was removed'
      assert_select 'li.schema-card[data-schema-path]', false, 'sort-only data attribute must be gone'
      assert_select 'li.schema-card[data-schema-label]', false, 'sort-only data attribute must be gone'
    ensure
      sign_out(@current_user)
    end

    # ---- #50201 follow-up: all chips share one row, type chips carry an icon ---
    test 'GET /schema/:id merges type/flag chips into one .schema-card__tags row, with a type icon and no link icons' do
      presenter, = first_detail_property_where { |p| p.expected_type.present? }
      skip 'no template exposes an expected-type chip in this instance' if presenter.nil?

      sign_in(@current_user)
      get schema_details_path(id: presenter.template_name)

      assert_response :success
      assert_select 'div.schema-card__tags', minimum: 1
      assert_select 'div.schema-card__types', false, 'the old types row must be merged into __tags'
      assert_select 'div.schema-card__flags', false, 'the old flags row must be merged into __tags'
      # each expected-type chip now leads with a Font Awesome type icon …
      assert_select '.schema-card__tags .schema-tag .fa', minimum: 1
      # … and the former external-link glyph is gone from every chip/link
      assert_select 'i.fa-external-link', false

      sign_out(@current_user)
    end

    # ---- #50201 follow-up: flag chips use the app tooltip, not native title ----
    # (skip guard runs before sign_in, so no ensure/sign_out is needed on skip —
    # mirrors the embedded/linked test's pattern and satisfies Minitest/SkipEnsure)
    test 'GET /schema/:id renders flag chips with data-dc-tooltip instead of a native title' do
      presenter, = first_detail_property_where { |p| p.flags.any? { |_, active| active } }
      skip 'no property carries an active flag in this instance' if presenter.nil?

      sign_in(@current_user)
      get schema_details_path(id: presenter.template_name)

      assert_response :success
      assert_select 'span.schema-tag[data-dc-tooltip]', minimum: 1
      assert_select '.schema-card__tags span.schema-tag[title]', false, 'flag chips must not use a native title tooltip'

      sign_out(@current_user)
    end

    # ---- #50201 follow-up: schema.org link renders without its icon on detail --
    test 'GET /schema/:id renders the schema.org link without the external-link icon' do
      document = DataCycleCore::Schema::Document.new(locale: I18n.default_locale)
      template = DataCycleCore::ThingTemplate.all.find do |thing_template|
        presenter = document.template(thing_template.template_name)
        presenter && schema_org_type(presenter.api_schema_types).present?
      end
      skip 'no template resolves to a schema.org type in this instance' if template.nil?

      sign_in(@current_user)
      get schema_details_path(id: template.template_name)

      assert_response :success
      assert_select 'a.schema-org-link'
      assert_select 'a.schema-org-link .fa', false, 'the detail view passes show_icon: false to the shared partial'

      sign_out(@current_user)
    end

    # ---- Deliverable: the grid is driven by two schema toggle buttons ---------
    # The overview is split into two schemas via two mutually-exclusive buttons:
    # "Hauptschema" (the main schema — entity + container) and "Embedded-Schema".
    # The former "Alle / Inhalte" content-type sub-filter is gone. Hauptschema is
    # pre-selected, each button carries its own template count, and every card is
    # tagged with the schema it belongs to so embedded contents never appear under
    # Hauptschema.
    test 'GET /schema drives the grid with two schema toggle buttons and no content-type sub-filter' do
      sign_in(@current_user)
      get schema_path

      assert_response :success

      assert_not_empty expected_groups, 'test DB has no templates to group'

      # the former content-type filter (Alle / Inhalte / …) is fully removed
      assert_select '[data-schema-filter]', false,
                    'the content-type sub-filter must be gone; the schema toggle replaces it'

      # main schema is pre-selected and counts the non-embedded templates
      assert_select 'button[data-schema-part="main"].is-active'
      assert_select 'button[data-schema-part="main"] .schema-part__count', text: main_total.to_s

      # the embedded button is only offered when embedded templates exist, is NOT
      # pre-selected, and counts the embedded group (never mixed into main's count)
      if embedded_templates.present?
        assert_select 'button[data-schema-part="embedded"]:not(.is-active)'
        assert_select 'button[data-schema-part="embedded"] .schema-part__count', text: embedded_templates.size.to_s
      else
        assert_select 'button[data-schema-part="embedded"]', false,
                      'no embedded button when the instance has no embedded templates'
      end

      # every card declares which schema it belongs to; embedded cards carry
      # data-part="embedded" (so the toggle can keep them out of Hauptschema),
      # every other card data-part="main"
      css_select('.schema-card').each do |card|
        expected_part = card['data-type'] == 'embedded' ? 'embedded' : 'main'

        assert_equal expected_part, card['data-part'],
                     "card #{card.at_css('a.schema-card__link')&.[]('href')} must be tagged data-part=#{expected_part}"
      end
    ensure
      sign_out(@current_user)
    end

    # ---- Deliverable: "nur mit Inhalten" toggle (thing count > 0) -------------
    # An independent toggle narrows either schema to templates that actually hold
    # content. It is off by default (client-side, so the server just renders it
    # un-pressed) and works off each card's thing count, which is exposed as the
    # data-sort-count attribute schema_index_filter.js reads.
    test 'GET /schema offers a "nur mit Inhalten" toggle, off by default, backed by each card thing count' do
      sign_in(@current_user)
      get schema_path

      assert_response :success

      assert_select 'button[data-schema-with-content]'                       # the toggle exists
      assert_select 'button[data-schema-with-content][aria-pressed="false"]' # off by default
      assert_select 'button[data-schema-with-content].is-active', false, 'the content toggle must start inactive'

      # the toggle filters on the count the cards already expose (see the sort
      # attribute test) — assert every card carries a numeric thing count so the
      # "count > 0" filter has something to read
      css_select('.schema-card').each do |card|
        assert_match(/\A\d+\z/, card['data-sort-count'].to_s,
                     "card #{card.at_css('a.schema-card__link')&.[]('href')} must expose a numeric thing count")
      end
    ensure
      sign_out(@current_user)
    end

    # The graph payload schema_dependency_graph.js consumes, rendered by the
    # schema/_graph_data partial. It carries the node/edge graph plus every label and
    # detail path the component needs, so the component itself needs neither i18n nor URL
    # templating — and it is the one place where a broken partial local would surface as an
    # empty graph rather than an exception.
    test 'GET /schema embeds the dependency graph payload the component consumes' do
      sign_in(@current_user)
      get schema_path

      assert_response :success
      assert_select 'script[type="application/json"][data-graph-data]', count: 1 do |elements|
        payload = JSON.parse(elements.first.text)

        assert_equal DataCycleCore::SchemaController::GRAPH_VIEWS.keys.map(&:to_s), payload['views']
        assert_predicate payload['nodes'], :present?, 'the payload carries no nodes'
        # the labels the component renders come from the partial, resolved in the
        # requested schema language — never a raw i18n key or a missing translation
        assert_equal(
          I18n.t('data_cycle_core.schema.dependencies.title', locale: @schema_language || I18n.default_locale),
          payload.dig('labels', 'dependencies')
        )
        # non-external nodes carry their finished detail path
        internal = payload['nodes'].find { |node| node['group'] != 'external' }
        assert_equal schema_details_path(internal['id']), internal['path'] if internal
      end
    ensure
      sign_out(@current_user)
    end

    # ---- Deliverable: dependency ("Abhängigkeiten") view ----------------------
    # A third tab renders the parent → embedded composition as a collapsible tree.
    # Roots are the non-embedded templates that embed something; each embedded
    # property is an edge to the embedded template (recursively). Nodes link to
    # their detail page. Everything is derived from the schema, so the assertions
    # track the live config.
    test 'GET /schema renders a dependency tab and a parent-to-embedded tree' do
      roots = dependency_roots
      skip 'no embedded dependencies configured in this instance' if roots.empty?

      sign_in(@current_user)
      get schema_path

      assert_response :success

      # third tab, not pre-selected, counting every template with at least one
      # connection (reference/shared/geo) — the same rows the tree below lists,
      # not just the (narrower) parent-to-embedded roots
      assert_select 'button[data-schema-part="deps"]:not(.is-active)'
      assert_select 'button[data-schema-part="deps"] .schema-part__count', text: dependency_rows.size.to_s

      # the tree container, its expand/collapse control, and collapsible nodes
      assert_select '[data-schema-deps]'
      assert_select '[data-schema-expand-all]'
      assert_select 'details[data-schema-dep]', minimum: 1

      # a real parent → embedded edge is present: the root and its embedded target
      # both link to their detail pages inside the tree
      root = roots.min_by(&:template_name) # controller sorts roots by name
      _key, target = embedded_edges_for(root).first

      assert_select '[data-schema-deps] a.schema-rel__name[href=?]', schema_details_path(root.template_name), minimum: 1
      assert_select '[data-schema-deps] a.schema-rel__name[href=?]', schema_details_path(target), minimum: 1

      sign_out(@current_user)
    end

    # ---- Deliverable: overlay templates are hidden from the overview entirely --
    # (skip guards run before sign_in, so no ensure/sign_out is needed on skip —
    # mirrors the embedded/linked test's pattern and satisfies Minitest/SkipEnsure)
    test 'GET /schema does not render a card for any overlay template' do
      overlays = overlay_template_names
      skip 'no overlay templates configured in this instance' if overlays.blank?

      sign_in(@current_user)
      get schema_path

      assert_response :success

      overlays.each do |template_name|
        assert_select "a.schema-card__link[href='/schema/#{template_name}']", false,
                      "overlay template #{template_name} must not be shown on the overview"
      end

      sign_out(@current_user)
    end

    # ---- Deliverable: one card per template, tagged with its content type -----
    test 'GET /schema renders one card per template with the correct content-type tag and detail link' do
      sign_in(@current_user)
      get schema_path

      assert_response :success

      groups = expected_groups

      assert_not_empty groups, 'test DB has no templates to render'

      cards = css_select('.schema-card')
      expected_total = groups.sum { |_, templates| templates.size }

      assert_equal expected_total, cards.size, 'one card per template'

      groups.each do |content_type, templates|
        cards_of_type = cards.select { |c| c['data-type'] == content_type }

        assert_equal templates.size, cards_of_type.size, "cards tagged #{content_type}"

        templates.each do |template|
          href = schema_details_path(template.template_name)
          card = cards.find { |c| c.at_css('a.schema-card__link')&.[]('href') == href }

          assert card, "missing card linking to #{href}"
          assert_equal content_type, card['data-type']
        end
      end
    ensure
      sign_out(@current_user)
    end

    # ---- Deliverable: client-side search payload per card ---------------------
    test 'GET /schema tags every card with a lower-cased search payload of schema + template name' do
      sign_in(@current_user)
      get schema_path

      assert_response :success

      groups = expected_groups

      assert_not_empty groups, 'test DB has no templates to render'

      groups.flat_map(&:last).each do |template|
        href = schema_details_path(template.template_name)
        card = css_select('.schema-card').find { |c| c.at_css('a.schema-card__link')&.[]('href') == href }

        assert card, "missing card for #{template.template_name}"

        expected_search = "#{display_name_for(template)} #{template.template_name}".downcase

        assert_equal expected_search, card['data-search']
      end
    ensure
      sign_out(@current_user)
    end

    # ---- Deliverable: thing_count per template comes from the DB (not faked) --
    test 'GET /schema shows each template thing_count consistent with the database' do
      sign_in(@current_user)
      get schema_path

      assert_response :success

      groups = expected_groups

      assert_not_empty groups, 'test DB has no templates to render'

      groups.flat_map(&:last).each do |template|
        href = schema_details_path(template.template_name)
        card = css_select('.schema-card').find { |c| c.at_css('a.schema-card__link')&.[]('href') == href }

        assert card, "missing card for #{template.template_name}"

        count_el = card.at_css('.schema-card__count')

        assert count_el, "missing thing_count for #{template.template_name}"
        rendered = count_el.text.gsub(/\D/, '').to_i

        assert_equal db_thing_count(template), rendered, "thing_count for #{template.template_name}"
      end
    ensure
      sign_out(@current_user)
    end

    test 'GET /schema reflects a newly created content in the template thing_count' do
      template = creatable_template
      skip 'no creatable template with a plain name field found' if template.nil?

      before_count = db_thing_count(template)
      created = create_content(template.template_name, { 'name' => "schema-index-test-#{template.template_name}" }, @current_user)
      skip "could not create content for #{template.template_name}" if created.blank?

      assert_equal before_count + 1, db_thing_count(template), 'guard: content really created'

      sign_in(@current_user)
      get schema_path

      assert_response :success

      href = schema_details_path(template.template_name)
      card = css_select('.schema-card').find { |c| c.at_css('a.schema-card__link')&.[]('href') == href }

      assert card, "missing card for #{template.template_name}"
      rendered = card.at_css('.schema-card__count').text.gsub(/\D/, '').to_i

      assert_equal db_thing_count(template), rendered
      assert_operator rendered, :>=, 1
    end

    # ---- Deliverable: cards are arranged in schema.org type groups ------------
    test 'GET /schema arranges cards in schema.org type groups (largest first), sorted within each group' do
      sign_in(@current_user)
      get schema_path

      assert_response :success

      expected = expected_type_groups

      assert_not_empty expected, 'test DB has no templates to render'

      sections = css_select('.schema-group')

      # one section per schema.org top-level type, in the presenter order
      # (largest group first, ties alphabetical)
      assert_equal(expected.map(&:first), sections.pluck('data-schema-group'))

      # within each section the cards follow the presenter's within-group order
      expected.each_with_index do |(type, templates), index|
        rendered_order = sections[index].css('a.schema-card__link').map { |a| a['href'] }
        expected_order = templates.map { |t| schema_details_path(t.template_name) }

        assert_equal expected_order, rendered_order, "card order in the #{type} group"
      end

      # every card still lives inside exactly one type group (no stray cards)
      assert_equal(css_select('.schema-card').size,
                   sections.sum { |s| s.css('.schema-card').size })
    ensure
      sign_out(@current_user)
    end

    # ==================== XLSX export ==========================================

    test 'GET /schema.xlsx with a signed-in session returns the spreadsheet export' do
      sign_in(@current_user)

      get schema_path(format: :xlsx)

      assert_response :success
      assert_predicate response.body, :present?
      assert_includes response.media_type.to_s, 'spreadsheetml'
    ensure
      sign_out(@current_user)
    end

    test 'GET /schema.xlsx contains one worksheet per container and entity template' do
      sign_in(@current_user)
      get schema_path(format: :xlsx)

      assert_response :success

      # exactly the container + entity templates, each as its own worksheet named
      # after the template (matched by name, so a missing/mis-named/duplicated
      # sheet is caught — not just a wrong count). Overlay templates are excluded
      # here just as they are from the index grid (review 2.1), so the two /schema
      # surfaces stay consistent.
      overlays = overlay_template_names
      expected_names = ['container', 'entity'].flat_map { |ct| DataCycleCore::Schema.templates_with_content_type(ct) }
        .reject { |t| overlays.include?(t.template_name) }
        .map { |t| t.template_name.parameterize(separator: ' ', preserve_case: true).truncate(31) }

      assert_not_empty expected_names, 'test DB has no exportable templates'

      assert_equal expected_names.sort, xlsx_sheet_names(response.body).sort
    ensure
      sign_out(@current_user)
    end

    # ---- review 2.1: overlay templates are excluded from the XLSX, like the index
    # The index grid and the dependency view hide overlay templates; the XLSX
    # export must not diverge by giving an overlay its own worksheet. An overlay
    # that is embedded never becomes a top-level sheet anyway, so this positively
    # bites where an overlay is a container/entity template — but the invariant
    # "no overlay is ever a worksheet" is asserted regardless, tracking the live
    # config. (skip guard runs before sign_in, so no ensure/sign_out on skip.)
    test 'GET /schema.xlsx exports no worksheet for an overlay template' do
      overlays = overlay_template_names
      skip 'no overlay templates configured in this instance' if overlays.blank?

      sign_in(@current_user)
      get schema_path(format: :xlsx)

      assert_response :success

      sheet_names = xlsx_sheet_names(response.body)
      overlays.each do |template_name|
        overlay_sheet = template_name.parameterize(separator: ' ', preserve_case: true).truncate(31)

        assert_not_includes sheet_names, overlay_sheet,
                            "overlay template #{template_name} must not get its own worksheet"
      end

      sign_out(@current_user)
    end

    # ---- review 2.1: a template with zero documented properties must not crash
    # the workbook. When PropertyFilter.documented? filters out every property the
    # node list is empty; before the guard `rows.map(&:size).max` was nil and the
    # `('A'.ord + nil - 1)` column math raised TypeError, aborting the ENTIRE
    # export (every sheet), not just the empty one. The guard must instead emit a
    # title-only "no documented properties" sheet and let the export succeed.
    # We force the empty case for every template by stubbing the presenter, so the
    # test bites regardless of the fixture data (which currently has no empty one).
    test 'GET /schema.xlsx renders a title-only sheet for a template with no documented properties' do
      empty_presenter = Struct.new(:nodes).new([])

      sign_in(@current_user)
      DataCycleCore::Schema::XlsxPropertyPresenter.stub(:new, ->(*, **) { empty_presenter }) do
        get schema_path(format: :xlsx)
      end

      assert_response :success

      # the export still produced a sheet per exported template (no crash) ...
      assert_not_empty xlsx_sheet_names(response.body), 'the workbook must still contain sheets'

      # ... and each empty template carries the localized placeholder row instead
      # of numeric column data. Accept either configured locale (de/en) since the
      # export renders in the request's ambient locale.
      placeholders = [
        I18n.t('data_cycle_core.schema.xlsx.no_documented_properties', locale: :de),
        I18n.t('data_cycle_core.schema.xlsx.no_documented_properties', locale: :en)
      ]
      cells = xlsx_cell_strings(response.body)

      assert(placeholders.intersect?(cells),
             "expected a no-documented-properties placeholder row (one of #{placeholders.inspect})")
    ensure
      sign_out(@current_user)
    end

    # ---- Deliverable: the property column exports api_name, not the raw key ---
    test 'GET /schema.xlsx exports the api_name of a property, not its internal key' do
      renamed = api_renamed_property
      skip 'no exported template has an api-renamed property' if renamed.nil?

      _template, key, api_name = renamed

      sign_in(@current_user)
      get schema_path(format: :xlsx)

      assert_response :success

      cells = xlsx_cell_strings(response.body)

      # The api_name is a genuine v4 rename (e.g. "dc:slug"), distinct from the
      # raw key AND from its plain camelization, so it can only appear in the
      # export because the identifier column now emits api_name; before the switch
      # that column held the raw key and this value appeared nowhere.
      assert_not_equal key.camelize(:lower), api_name, 'guard: property is genuinely api-renamed, not just camelCased'
      assert_includes cells, api_name, "expected the api_name #{api_name.inspect} in the export"
    end

    private

    # Asserts the light/dark toggle (schema/theme_toggle.js)
    # renders in its default, unpressed state with its data-label-* attributes
    # localized to `locale`, against whatever response the caller already fetched.
    # Shared by the language-switcher tests so checking it never costs an extra
    # request per locale (mirrors OpenApiViewerTest#assert_viewer_chrome_localised).
    def assert_theme_toggle_localized(locale)
      assert_select 'button.schema-theme-toggle[data-schema-theme-toggle][aria-pressed="false"]' do |elements|
        toggle = elements.first

        assert_equal I18n.t('data_cycle_core.schema.theme.toggle_dark', locale:), toggle['data-label-dark'],
                     "data-label-dark must render schema.theme.toggle_dark for #{locale}"
        assert_equal I18n.t('data_cycle_core.schema.theme.toggle_light', locale:), toggle['data-label-light'],
                     "data-label-light must render schema.theme.toggle_light for #{locale}"
      end
      assert_select 'button.schema-theme-toggle i.fa.fa-moon-o'
    end

    # Pick, at runtime, an EXPORTED template-thing (the very objects the view
    # loops over) that has a top-level property carrying a GENUINE v4 api rename —
    # i.e. an api_name that differs from the plain camelization of the key. That
    # rules out default camelCasing: such a value (e.g. "dc:slug", "url") can only
    # appear in the export because the api config was consulted, which makes it a
    # sound discriminator. Returns [template_thing, key, api_name] or nil.
    def api_renamed_property
      overlays = overlay_template_names
      exported = ['container', 'entity'].flat_map { |ct| DataCycleCore::Schema.templates_with_content_type(ct) }
        .reject { |t| overlays.include?(t.template_name) }

      exported.each do |template|
        (template.schema['properties'] || {}).each do |key, definition|
          next if definition['type'] == 'key'

          api_name = template.api_name_for(key, definition)
          next if api_name.blank? || api_name == key || api_name == key.camelize(:lower)

          return [template, key, api_name]
        end
      end
      nil
    end

    # First entity template that has a plain translated/column "name" property,
    # so create_content with { name: … } succeeds. Returns a ThingTemplate or nil.
    def creatable_template
      DataCycleCore::ThingTemplate.where(content_type: ['entity', 'container']).find_each do |template|
        definition = template.schema.dig('properties', 'name')
        next if definition.blank? || definition['type'] == 'key'

        return template unless DataCycleCore::Thing.new(template_name: template.template_name).template_missing?
      end
      nil
    end

    # Zip::File.open_buffer returns the buffer, not the block value, so results
    # are collected into a local and returned after the block.
    def xlsx_entry_xml(binary, entry_name)
      doc = nil
      Zip::File.open_buffer(StringIO.new(binary)) do |zip|
        entry = zip.find_entry(entry_name)
        next if entry.nil?

        doc = Nokogiri::XML(entry.get_input_stream.read)
        doc.remove_namespaces!
      end
      doc
    end

    def xlsx_sheet_names(binary)
      doc = xlsx_entry_xml(binary, 'xl/workbook.xml')
      return [] if doc.nil?

      doc.xpath('//sheets/sheet').map { |sheet| sheet.attr('name') }
    end

    # caxlsx writes inline strings into the worksheet XMLs (no sharedStrings.xml
    # by default), so gather every <t> text node from the worksheets (and shared
    # strings if present). Returns the list of string cell values.
    def xlsx_cell_strings(binary)
      strings = []
      Zip::File.open_buffer(StringIO.new(binary)) do |zip|
        zip.each do |entry|
          next unless entry.name == 'xl/sharedStrings.xml' || entry.name.match?(%r{\Axl/worksheets/sheet\d+\.xml\z})

          doc = Nokogiri::XML(entry.get_input_stream.read)
          doc.remove_namespaces!
          strings.concat(doc.xpath('//t').map(&:text))
        end
      end
      strings
    end
  end
end
