# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationHelperTest < ActionView::TestCase
    include DataCycleCore::ClassificationHelper
    include DataCycleCore::UiLocaleHelper

    delegate :logger, to: :Rails

    # concept_tooltip gates the external URI on an ability (#27657) and ActionView::TestCase has
    # no controller to answer can?, so it is answered here - permissive unless a test denies an action,
    # matching the `def can?(*) = true` stubs in the other helper tests.
    def can?(action, _subject = nil) = Array.wrap(@denied_abilities).exclude?(action)

    ColorDouble = Struct.new(:has_color, :color) do
      def color? = has_color
    end

    ConceptDouble = Struct.new(:full_path, :description, :name_i18n, :uri) do
      def first_available_locale(_default = nil) = :de
    end

    test 'matched_concept_path wraps matches in mark tags' do
      assert_equal 'Hello World', matched_concept_path('Hello World', [])
      assert_equal '', matched_concept_path('', ['x'])
      assert_equal 'Hello <mark>World</mark>', matched_concept_path('Hello World', ['World'])
      assert_equal 'Hello', matched_concept_path('Hello', ['xyz'])
    end

    test 'concept_title reads the internal name, the external key or DELETED' do
      assert_equal 'DELETED', concept_title(Object.new)
      assert_equal 'Internal', concept_title(DataCycleCore::Concept.new(internal_name: 'Internal'))
      assert_equal 'key', concept_title(DataCycleCore::Concept.new(external_key: 'key'))
      assert_equal 'NO_NAME', concept_title(DataCycleCore::Concept.new)
    end

    test 'concept_scheme_name resolves the owning scheme name' do
      concept = DataCycleCore::Concept.for_tree('Inhaltstypen').first

      assert_equal 'Inhaltstypen', concept_scheme_name(concept)
      assert_nil concept_scheme_name(nil)
    end

    # #43524: backs the classification-usage chip on the saved-searches page (see
    # StoredFiltersController#saved_searches) - takes the already-resolved record (see
    # StoredFilter.classification_usage_record), not an id, so this stays pure presentation logic.
    test 'classification_usage_titles returns the tree label name and the title for a concept' do
      concept = DataCycleCore::Concept.for_tree('Inhaltstypen').first

      assert_equal ['Inhaltstypen', concept.internal_name], classification_usage_titles(concept)
    end

    test 'classification_usage_titles uses the tree label name as the group label and a generic "all" value for a concept_scheme' do
      concept_scheme = DataCycleCore::ConceptScheme.find_by(name: 'Inhaltstypen')

      assert_equal ['Inhaltstypen', I18n.t('data_cycle_core.stored_searches.classification_usage_all', locale: active_ui_locale)], classification_usage_titles(concept_scheme)
    end

    test 'classification_usage_titles is nil for neither a concept nor a concept_scheme' do
      assert_nil classification_usage_titles(nil)
    end

    test 'concept_color_style returns a css variable only when a color is set' do
      assert_nil concept_color_style(nil)
      assert_nil concept_color_style(ColorDouble.new(false, nil))
      assert_equal '--classification-color: #fff;', concept_color_style(ColorDouble.new(true, '#fff'))
    end

    test 'concept_scheme_visibility_icon maps the visibility to an icon' do
      assert_includes concept_scheme_visibility_icon('list'), 'fa-th-list'
      assert_includes concept_scheme_visibility_icon('tree_view'), 'fa-sitemap'
      assert_includes concept_scheme_visibility_icon('unknown'), 'fa-info-circle'
    end

    test 'async_concept_select_options is an empty select for a blank value' do
      assert_equal '', async_concept_select_options(nil)
    end

    test 'group_key_for_concept_scheme uses the external source name when present' do
      assert_equal 'Feratel', group_key_for_concept_scheme(struct_double(external_system_id: 5), { 5 => struct_double(name: 'Feratel') })
      assert_equal 5, group_key_for_concept_scheme(struct_double(external_system_id: 5), {})
    end

    test 'concept_tooltip is nil for a nil concept' do
      assert_nil concept_tooltip(nil)
    end

    test 'concept_tooltip renders the full path' do
      assert_includes concept_tooltip(ConceptDouble.new('A > B', nil, {})), 'tag-full-path'
    end

    test 'concept_tooltip lists grouped translations' do
      html = concept_tooltip(ConceptDouble.new('A', nil, { 'de' => 'Name', 'en' => 'Name' }))

      assert_includes html, 'tag-translations'
    end

    # #27657: the external URI is the only value that reliably tells near-identically named concepts
    # apart while mapping them, so it is labelled with the model's own attribute translation instead
    # of being printed bare - not every uri is URL-shaped (some hold foreign ids).
    test 'concept_tooltip renders the labelled external uri' do
      html = concept_tooltip(ConceptDouble.new('A', nil, {}, 'https://creativecommons.org/licenses/by/4.0/'))

      assert_includes html, 'tag-uri'
      assert_includes html, DataCycleCore::Concept.human_attribute_name(:uri, locale: active_ui_locale)
      assert_includes html, 'https://creativecommons.org/licenses/by/4.0/'
    end

    test 'concept_tooltip omits the uri section without a uri' do
      assert_not_includes concept_tooltip(ConceptDouble.new('A', nil, {}, nil)), 'tag-uri'
      assert_not_includes concept_tooltip(ConceptDouble.new('A', nil, {}, '')), 'tag-uri'
      assert_not_includes concept_tooltip(ConceptDouble.new('A', nil, {}, nil)), DataCycleCore::Concept.human_attribute_name(:uri, locale: active_ui_locale)
    end

    test 'concept_tooltip hides the external uri without the show_uri ability' do
      @denied_abilities = [:show_uri]

      html = concept_tooltip(ConceptDouble.new('A > B', 'Beschreibung', { 'de' => 'Name', 'en' => 'Name' }, 'https://creativecommons.org/licenses/by/4.0/'))

      assert_not_includes html, 'tag-uri'
      assert_not_includes html, 'https://creativecommons.org/licenses/by/4.0/'
      assert_not_includes html, DataCycleCore::Concept.human_attribute_name(:uri, locale: active_ui_locale)
      assert_includes html, 'tag-full-path'
      assert_includes html, 'tag-description'
      assert_includes html, 'tag-translations'
    end

    test 'concept_tooltip escapes the external uri' do
      html = concept_tooltip(ConceptDouble.new('A', nil, {}, '"><script>alert(1)</script>'))

      assert_not_includes html, '<script>'
      assert_includes html, '&lt;script&gt;'
    end

    test 'grouped_concept_scheme_visibilities returns one entry per visibility group' do
      result = grouped_concept_scheme_visibilities(struct_double(id: 'cs-1'))

      assert_kind_of Array, result
      assert result.first.key?(:key)
    end

    test 'async_concept_select_options builds options from concepts' do
      concept = DataCycleCore::Concept.for_tree('Inhaltstypen').first

      html = async_concept_select_options([concept])

      assert_includes html, concept.internal_name
    end

    test 'group_key_for_concept_scheme matches an external system by name similarity' do
      es = { 'x' => struct_double(name: 'Feratel', identifier: 'feratel') }
      scheme = struct_double(external_system_id: nil, name: 'Feratel Tirol')

      assert_equal 'Feratel', group_key_for_concept_scheme(scheme, es)
    end

    # #41458: both image detail partials built this inline and both asked the concept for a
    # classification_id, which raised on every image detail page.
    test 'gravity_concepts_json exposes the gravity, id and name of each Gravity concept' do
      entries = JSON.parse(gravity_concepts_json)

      assert_kind_of Array, entries
      assert_equal DataCycleCore::Concept.for_tree('Gravity').count, entries.size
      assert(entries.all? { |e| e.keys.sort == ['gravity', 'id', 'name'] })
      assert_equal DataCycleCore::Concept.for_tree('Gravity').pluck(:id).to_set, entries.pluck('id').to_set
    end

    test 'concept_scheme_ccc_count counts distinct things via collected classification contents' do
      count = concept_scheme_ccc_count(
        struct_double(id: '00000000-0000-0000-0000-000000000000'),
        struct_double(things: DataCycleCore::Thing.none),
        'related'
      )

      assert_equal 0, count
    end
  end
end
