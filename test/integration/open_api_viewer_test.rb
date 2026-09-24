# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Request-level coverage for the hosted OpenAPI (Swagger UI) viewer page (#50192).
  # Complements the unit-level OpenApiViewerControllerTest (which only exercises the
  # `spec_language` allowlist) and AuthenticationTest (which covers the JSON spec
  # endpoint via token). Here we drive the actual route + `Accept: text/html`
  # constraint, the session auth, the Swagger UI mount that loads the per-instance
  # spec from GET /api/config/openapi, the locale switcher, and the self-contained
  # (locally bundled, no external CDN) assets — i.e. the story's acceptance criteria.
  #
  # Everything is derived from I18n / the routes at runtime, so the suite tracks the
  # live locale configuration instead of hard-coding it.
  class OpenApiViewerTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    include DataCycleCore::I18nTestHelper

    # the route only serves the viewer to real browsers (Accept: text/html); API
    # clients/curl fall through to the JSON spec endpoint on the same path.
    HTML_HEADERS = { 'Accept' => 'text/html' }.freeze

    # Every user-facing viewer-chrome string, mapped to where it is rendered and
    # to the data_cycle_core.openapi_viewer.* i18n key it must carry. One source
    # of truth for "which key renders where" so a new label can't skip the guard.
    # `[selector, attribute]` — a nil attribute means the element's text content.
    CHROME_HTML = {
      'search' => ['input#ov-nav-search', 'placeholder'],
      'clear_search' => ['button#ov-nav-search-clear', 'aria-label'],
      'no_results' => ['#ov-palette-empty', nil]
    }.freeze

    # Labels the view hands to the Swagger UI JS via data-label-* attributes on
    # the mount (attribute suffix => i18n key).
    CHROME_DATA_LABELS = {
      'overview' => 'overview', 'schemas' => 'schemas', 'details' => 'details',
      'access-denied' => 'access_denied', 'spec-error' => 'spec_error', 'toggle-group' => 'toggle_group',
      'expandable-to' => 'expandable_to'
    }.freeze

    # Labels the light/dark toggle button (openapi_viewer/theme_toggle.js) hands
    # itself via data-label-* attributes (attribute suffix => i18n key under
    # data_cycle_core.openapi_viewer.theme).
    THEME_TOGGLE_DATA_LABELS = {
      'dark' => 'theme.toggle_dark', 'light' => 'theme.toggle_light'
    }.freeze

    before(:all) do
      @routes = Engine.routes
      # Any signed-in user reaches the viewer (it checks no :api_config_* subject); that a
      # low-privilege session gets the same page is covered by AuthenticationTest.
      @current_user = DataCycleCore::User.find_by(email: 'system_admin@datacycle.at')
    end

    # -------------------- auth --------------------
    test 'GET the viewer without a session redirects to the sign-in page' do
      get openapi_viewer_path, headers: HTML_HEADERS

      assert_response :redirect
      assert_match(/sign_in/, response.location)
    end

    # The viewer is a standalone docs page: it renders through open_api_viewer.html.erb,
    # which uses application/_head_base and ships only entrypoints/openapi_viewer.js.
    # Pulling in application.js/application.scss would add the whole backend bundle for
    # markup that uses none of it.
    test 'the viewer page loads its own entrypoint and not the application bundle' do
      sign_in(@current_user)

      get openapi_viewer_path, headers: HTML_HEADERS

      assert_response :success
      assert_match(/openapi_viewer/, response.body, 'the viewer entrypoint must be requested')
      assert_no_match(%r{entrypoints/application\.js|application\.scss}, response.body,
                      'the standalone viewer layout must not load the application bundle')
    ensure
      sign_out(@current_user)
    end

    # -------------------- renders the Swagger UI shell --------------------
    test 'GET the viewer with a signed-in session renders the Swagger UI shell (AK1)' do
      sign_in(@current_user)

      get openapi_viewer_path, headers: HTML_HEADERS

      assert_response :success
      assert_select 'main.ov-shell'
      assert_select '#swagger-ui', count: 1
    ensure
      sign_out(@current_user)
    end

    # -------------------- no-store shell (guards against stale content-hashed Vite assets) --------------------
    # The shell HTML references content-hashed Vite assets; a cached page would keep
    # loading stale JS/CSS after a rebuild. The controller sets Cache-Control: no-store
    # so the browser always refetches the shell (assets stay long-cached by hash).
    test 'GET the viewer marks the shell HTML as no-store so it is never served stale' do
      sign_in(@current_user)

      get openapi_viewer_path, headers: HTML_HEADERS

      assert_response :success
      assert_equal 'no-store', response.headers['Cache-Control']
    ensure
      sign_out(@current_user)
    end

    # -------------------- light/dark toggle (behaviour: openapi_viewer/theme_toggle.js) --------------------
    # Server-rendered default state: unpressed, moon icon (switch-to-dark
    # affordance) — theme_toggle.js takes over from here client-side, so this
    # only guards the markup its JS depends on (selector, aria-pressed, icon).
    test 'GET the viewer renders the light/dark toggle in its default (light, unpressed) state' do
      sign_in(@current_user)

      get openapi_viewer_path, headers: HTML_HEADERS

      assert_response :success
      assert_select 'main.ov-shell button.ov-theme-toggle[data-ov-theme-toggle][aria-pressed="false"]', count: 1
      assert_select 'button.ov-theme-toggle i.fa.fa-moon-o'
    ensure
      sign_out(@current_user)
    end

    # -------------------- loads the per-instance spec (AK1) --------------------
    test 'the Swagger UI mount points at the per-instance OpenAPI document' do
      sign_in(@current_user)

      get openapi_viewer_path, headers: HTML_HEADERS

      assert_response :success
      assert_select '#swagger-ui[data-spec-url]' do |elements|
        spec_url = elements.first['data-spec-url']
        # points at GET /api/config/openapi; the viewer JS appends ?language= and
        # requests it as JSON (Accept header), so the URL itself carries no format.
        assert_includes spec_url, 'openapi', 'the mount should load the openapi document'
        assert_equal api_config_openapi_path, spec_url.split('?').first
      end
    ensure
      sign_out(@current_user)
    end

    # -------------------- locale switch (AK3) --------------------
    # The switcher offers the locales the document is *translated* into, not every
    # configured one: config/locales ships open_api.de.yml and open_api.en.yml only and
    # config.i18n.fallbacks is off, so an untranslated locale would render
    # "Translation missing: fr.open_api.info.description" as the description.
    test 'the viewer offers a locale switch for every translated locale and marks the active one' do
      translated = DataCycleCore::OpenApi::Translations.available_locales
      skip 'only a single locale is translated' if translated.size < 2

      requested = translated.include?(:en) ? :en : translated.first
      sign_in(@current_user)

      get openapi_viewer_path(language: requested), headers: HTML_HEADERS

      assert_response :success
      translated.each do |locale|
        assert_select %(a.ov-locale[href*="language=#{locale}"]), minimum: 1
      end
      (I18n.available_locales - translated).each do |locale|
        assert_select %(a.ov-locale[href*="language=#{locale}"]), count: 0
      end
      # the requested locale drives both the active marker and the spec language
      assert_select 'a.ov-locale.is-active', text: requested.to_s.upcase
      assert_select %(#swagger-ui[data-language="#{requested}"])

      sign_out(@current_user)
    end

    # Regression for the real controller (the unit test only covers the resolver): a
    # configured locale without open_api translations must not reach the switcher, and
    # asking for it must not render a translation-missing marker into the page.
    test 'a configured locale without open_api translations is not offered and never rendered' do
      # the staged locale carries the viewer's own chrome keys, so only the open_api.* ones
      # are missing — otherwise the page would fail for the wrong reason
      with_untranslated_locale(translations: { data_cycle_core: { openapi_viewer: { title: 'x' } } }) do |locale|
        sign_in(@current_user)

        get openapi_viewer_path(language: locale), headers: HTML_HEADERS

        assert_response :success
        assert_select %(a.ov-locale[href*="language=#{locale}"]), count: 0
        assert_select '#swagger-ui[data-language]' do |elements|
          assert_not_equal locale.to_s, elements.first['data-language']
        end
        assert_no_match(/translation missing/i, response.body)
      end
    ensure
      sign_out(@current_user)
    end

    # An unsupported language never reaches the page as-is; the rendered spec
    # language is clamped to a configured locale (deep sanitisation of slashes /
    # injection payloads is covered by OpenApiViewerControllerTest#spec_language).
    test 'an unsupported language param is clamped to a configured locale' do
      sign_in(@current_user)

      get openapi_viewer_path(language: 'not-a-locale'), headers: HTML_HEADERS

      assert_response :success
      assert_select '#swagger-ui[data-language]' do |elements|
        assert_includes I18n.available_locales.map(&:to_s), elements.first['data-language']
      end
    ensure
      sign_out(@current_user)
    end

    # -------------------- self-contained assets / no external CDN (AK4) --------------------
    test 'the viewer bundle is served locally, not from an external CDN' do
      sign_in(@current_user)

      get openapi_viewer_path, headers: HTML_HEADERS

      assert_response :success
      # the Swagger UI bundle is a locally-built vite asset served from this
      # instance's /assets path (in the test env vite prefixes the local host).
      assert_select 'script[src*="openapi_viewer"]', minimum: 1 do |elements|
        elements.each do |script|
          assert_match %r{/assets/}, script['src'], 'the viewer script must be a locally-built vite asset'
        end
      end
      # no external CDN / demo host is referenced anywhere in the page
      ['unpkg.com', 'jsdelivr.net', 'cdnjs.cloudflare.com', 'petstore.swagger.io'].each do |host|
        assert_not_includes response.body, host, "the viewer must not reference the external host #{host}"
      end
    ensure
      sign_out(@current_user)
    end

    # -------------------- chrome comes from i18n, not hardcoded, per requested locale --------------------
    # Every user-facing viewer-chrome string (the sidebar search field + its
    # clear/empty labels, and the data-label-* labels the JS renders) must be the
    # exact translation of its data_cycle_core.openapi_viewer.* key — never
    # hardcoded and never a raw "translation missing" fallback. Driven for every
    # configured locale via `?language=`, so a stale key surfaces in whichever
    # locale lacks it.
    test 'the viewer chrome is rendered from i18n for every configured locale' do
      sign_in(@current_user)

      I18n.available_locales.each do |locale|
        get openapi_viewer_path(language: locale), headers: HTML_HEADERS

        assert_response :success
        assert_viewer_chrome_localised(locale)
      end
    ensure
      sign_out(@current_user)
    end

    # Regression (#50201): the chrome must follow the *selected* viewer language
    # (@spec_language, from `?language=`), not the signed-in user's account UI
    # locale. Previously the sidebar used active_ui_locale, so switching to EN
    # still showed the German "API durchsuchen …" placeholder.
    test 'the viewer chrome follows the selected language, not the signed-in users ui_locale' do
      skip 'needs at least two configured locales' if I18n.available_locales.size < 2

      account_locale = (@current_user.ui_locale || DataCycleCore.ui_locales.first).to_sym
      requested = I18n.available_locales.find { |locale| locale != account_locale }

      sign_in(@current_user)
      get openapi_viewer_path(language: requested), headers: HTML_HEADERS

      assert_response :success
      # the whole chrome is in the requested language …
      assert_viewer_chrome_localised(requested)
      # … and specifically not falling back to the account UI locale
      selector, attribute = CHROME_HTML.fetch('search')
      assert_select selector do |elements|
        assert_not_equal I18n.t('data_cycle_core.openapi_viewer.search', locale: account_locale), elements.first[attribute],
                         'search placeholder must follow the selected language, not the account ui_locale'
      end

      sign_out(@current_user)
    end

    # Locale parity for the viewer's own UI strings: every configured locale must
    # define the exact same data_cycle_core.openapi_viewer.* key set (the open_api.*
    # spec texts are covered by TranslationsTest).
    test 'all locales define the same data_cycle_core.openapi_viewer keys' do
      key_sets = I18n.available_locales.index_with do |locale|
        I18n.t('data_cycle_core.openapi_viewer', locale:, default: {}).keys.sort
      end

      reference_locale, reference_keys = key_sets.first

      assert_predicate reference_keys, :present?, "no openapi_viewer keys found for #{reference_locale}"
      key_sets.each do |locale, keys|
        assert_equal reference_keys, keys, "openapi_viewer keys of #{locale} differ from #{reference_locale}"
      end
    end

    # -------------------- `.json` never resolves to the viewer (dual-serving) --------------------
    # The viewer route carries `format: false`, so it only matches the extension-less
    # path: /api/config/openapi.json must always fall through to the JSON spec endpoint
    # (and its auth guard), never render the HTML viewer — even for a browser.
    test 'GET /api/config/openapi.json as a browser falls through to the JSON endpoint, not the viewer' do
      get '/api/config/openapi.json', headers: HTML_HEADERS

      assert_response :unauthorized
      assert_equal 'application/json; charset=utf-8', response.content_type
    end

    test 'GET /api/config/openapi.json with a session returns the JSON document, not the viewer' do
      sign_in(@current_user)

      get '/api/config/openapi.json', headers: HTML_HEADERS

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
    ensure
      sign_out(@current_user)
    end

    # -------------------- renders without a running Vite dev server (CI / prod) --------------------
    # Regression guard (#50192): with no dev server the viewer must render from the
    # built manifest. dc_javascript_tag emits the entry's bundled stylesheet; the
    # manifest already returns a fully-resolved css href, so re-resolving it through
    # vite_asset_path raised ViteRuby::MissingEntrypointError mid-render (only when no
    # dev server runs — which is exactly CI, where this failed with 8 errors). The
    # test container usually runs a dev server, so we force the manifest path here.
    test 'the viewer renders in manifest mode (no dev server) and links its bundled stylesheet locally' do
      sign_in(@current_user)

      ViteRuby.instance.stub(:dev_server_running?, false) do
        get openapi_viewer_path, headers: HTML_HEADERS
      end

      assert_response :success
      assert_select '#swagger-ui', count: 1
      # the bundled css is served locally from this instance's /assets path, resolved
      # straight from the manifest (no external CDN)
      assert_select 'link[rel="stylesheet"][href*="openapi_viewer"]', minimum: 1 do |links|
        links.each { |link| assert_match %r{/assets/}, link['href'] }
      end
    ensure
      sign_out(@current_user)
    end

    # The layout ships no application bundle, so the viewer's own CSS has to carry what
    # the page uses from it. The icon font is the part that silently disappears: the
    # markup keeps rendering <i class="fa fa-search">, it just draws nothing. Derived
    # from the response so a newly added icon is covered without touching this test.
    test 'the viewer stylesheet defines every icon class the page renders' do
      sign_in(@current_user)

      ViteRuby.instance.stub(:dev_server_running?, false) do
        get openapi_viewer_path, headers: HTML_HEADERS
      end

      assert_response :success

      icons = response.body.scan(/class="fa (fa-[a-z0-9-]+)/).flatten.uniq

      assert_operator icons.size, :>, 0, 'expected the viewer chrome to render fa icons'

      css = viewer_stylesheet_source

      icons.each do |icon|
        assert_includes css, ".#{icon}:before", "#{icon} is rendered but not defined in the viewer bundle"
      end
      assert_match(/@font-face\{font-family:FontAwesome/, css, 'the bundle must ship the FontAwesome face itself')
    ensure
      sign_out(@current_user)
    end

    private

    # Source of the viewer's built stylesheet, read straight from the Vite build output
    # the manifest-mode response links to.
    def viewer_stylesheet_source
      href = css_select('link[rel="stylesheet"][href*="openapi_viewer"]').first['href']

      ViteRuby.config.build_output_dir.join(File.basename(href)).read
    end

    # Asserts every viewer-chrome string in the current response equals the
    # translation of its openapi_viewer.* key for `locale`, and that nothing
    # rendered a raw "translation missing" message. Shared by the per-locale and
    # the account-locale-independence tests so the "which key renders where"
    # knowledge lives only in CHROME_HTML / CHROME_DATA_LABELS.
    def assert_viewer_chrome_localised(locale)
      translate = ->(key) { I18n.t("data_cycle_core.openapi_viewer.#{key}", locale:) }

      CHROME_HTML.each do |key, (selector, attribute)|
        expected = translate.call(key)

        assert_predicate expected, :present?, "openapi_viewer.#{key} is blank for #{locale}"
        assert_select selector do |elements|
          actual = attribute ? elements.first[attribute] : elements.first.text.strip

          assert_equal expected, actual, "#{selector} must render openapi_viewer.#{key} for #{locale}"
        end
      end

      assert_select '#swagger-ui' do |elements|
        mount = elements.first

        CHROME_DATA_LABELS.each do |attribute, key|
          assert_equal translate.call(key), mount["data-label-#{attribute}"],
                       "data-label-#{attribute} must render openapi_viewer.#{key} for #{locale}"
        end
      end

      assert_select 'button.ov-theme-toggle[data-ov-theme-toggle]' do |elements|
        toggle = elements.first

        THEME_TOGGLE_DATA_LABELS.each do |attribute, key|
          assert_equal translate.call(key), toggle["data-label-#{attribute}"],
                       "data-label-#{attribute} must render openapi_viewer.#{key} for #{locale}"
        end
      end

      assert_no_match(/translation missing/i, response.body, "viewer chrome exposed a missing translation for #{locale}")
    end
  end
end
