# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ClassificationHelperTest < ActionView::TestCase
    include DataCycleCore::ClassificationHelper
    include DataCycleCore::UiLocaleHelper

    delegate :logger, to: :Rails

    # classification_tooltip gates the external URI on an ability (#27657) and ActionView::TestCase has
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

    test 'classification_title reads the name, internal name or DELETED' do
      assert_equal 'DELETED', classification_title(Object.new)
      assert_equal 'Tag', classification_title(DataCycleCore::Classification.new(name: 'Tag'))
      assert_equal 'Alias', classification_title(DataCycleCore::ClassificationAlias.new(internal_name: 'Alias'))
    end

    test 'classification_tree_label_name resolves the owning tree label name' do
      ca = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').first

      assert_equal 'Inhaltstypen', classification_tree_label_name(ca)
      assert_nil classification_tree_label_name(nil)
    end

    # #43524: backs the classification-usage chip on the saved-searches page (see
    # StoredFiltersController#saved_searches) - takes the already-resolved record (see
    # StoredFilter.classification_usage_record), not an id, so this stays pure presentation logic.
    test 'classification_usage_titles returns the tree label name and the title for a classification_alias' do
      ca = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').first

      assert_equal ['Inhaltstypen', ca.internal_name], classification_usage_titles(ca)
    end

    test 'classification_usage_titles uses the tree label name as the group label and a generic "all" value for a classification_tree_label' do
      tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')

      assert_equal ['Inhaltstypen', I18n.t('data_cycle_core.stored_searches.classification_usage_all', locale: active_ui_locale)], classification_usage_titles(tree_label)
    end

    test 'classification_usage_titles is nil for neither a classification_alias nor a classification_tree_label' do
      assert_nil classification_usage_titles(nil)
    end

    test 'classification_style returns a css variable only when a color is set' do
      assert_nil classification_style(nil)
      assert_nil classification_style(ColorDouble.new(false, nil))
      assert_equal '--classification-color: #fff;', classification_style(ColorDouble.new(true, '#fff'))
    end

    test 'expected_classification_alias unwraps a Classification' do
      assert_equal 'x', expected_classification_alias('x')
      assert_nil expected_classification_alias(DataCycleCore::Classification.new)
    end

    test 'expected_value_id resolves the id for the expected type' do
      direct = struct_double(id: 'direct')

      assert_equal 'direct', expected_value_id(direct, direct.class)
      assert_equal 'pc-1', expected_value_id(struct_double(primary_classification: struct_double(id: 'pc-1')), DataCycleCore::Classification)
      assert_equal 'pca-1', expected_value_id(struct_double(primary_classification_alias: struct_double(id: 'pca-1')), DataCycleCore::ClassificationAlias)
    end

    test 'concept_scheme_visibility_icon maps the visibility to an icon' do
      assert_includes concept_scheme_visibility_icon('list'), 'fa-th-list'
      assert_includes concept_scheme_visibility_icon('tree_view'), 'fa-sitemap'
      assert_includes concept_scheme_visibility_icon('unknown'), 'fa-info-circle'
    end

    test 'async_classification_select_options is an empty select for a blank value' do
      assert_equal '', async_classification_select_options(nil)
    end

    test 'group_key_for_ctl uses the external source name when present' do
      assert_equal 'Feratel', group_key_for_ctl(struct_double(external_source_id: 5), { 5 => struct_double(name: 'Feratel') })
      assert_equal 5, group_key_for_ctl(struct_double(external_source_id: 5), {})
    end

    test 'classification_tooltip is nil for a nil concept' do
      assert_nil classification_tooltip(nil)
    end

    test 'classification_tooltip renders the full path' do
      assert_includes classification_tooltip(ConceptDouble.new('A > B', nil, {})), 'tag-full-path'
    end

    test 'classification_tooltip lists grouped translations' do
      html = classification_tooltip(ConceptDouble.new('A', nil, { 'de' => 'Name', 'en' => 'Name' }))

      assert_includes html, 'tag-translations'
    end

    # #27657: the external URI is the only value that reliably tells near-identically named concepts
    # apart while mapping them, so it is labelled with the model's own attribute translation instead
    # of being printed bare - not every uri is URL-shaped (some hold foreign ids).
    test 'classification_tooltip renders the labelled external uri' do
      html = classification_tooltip(ConceptDouble.new('A', nil, {}, 'https://creativecommons.org/licenses/by/4.0/'))

      assert_includes html, 'tag-uri'
      assert_includes html, DataCycleCore::ClassificationAlias.human_attribute_name(:uri, locale: active_ui_locale)
      assert_includes html, 'https://creativecommons.org/licenses/by/4.0/'
    end

    test 'classification_tooltip omits the uri section without a uri' do
      assert_not_includes classification_tooltip(ConceptDouble.new('A', nil, {}, nil)), 'tag-uri'
      assert_not_includes classification_tooltip(ConceptDouble.new('A', nil, {}, '')), 'tag-uri'
      assert_not_includes classification_tooltip(ConceptDouble.new('A', nil, {}, nil)), DataCycleCore::ClassificationAlias.human_attribute_name(:uri, locale: active_ui_locale)
    end

    test 'classification_tooltip hides the external uri without the show_uri ability' do
      @denied_abilities = [:show_uri]

      html = classification_tooltip(ConceptDouble.new('A > B', 'Beschreibung', { 'de' => 'Name', 'en' => 'Name' }, 'https://creativecommons.org/licenses/by/4.0/'))

      assert_not_includes html, 'tag-uri'
      assert_not_includes html, 'https://creativecommons.org/licenses/by/4.0/'
      assert_not_includes html, DataCycleCore::ClassificationAlias.human_attribute_name(:uri, locale: active_ui_locale)
      assert_includes html, 'tag-full-path'
      assert_includes html, 'tag-description'
      assert_includes html, 'tag-translations'
    end

    test 'classification_tooltip escapes the external uri' do
      html = classification_tooltip(ConceptDouble.new('A', nil, {}, '"><script>alert(1)</script>'))

      assert_not_includes html, '<script>'
      assert_includes html, '&lt;script&gt;'
    end

    test 'grouped_concept_scheme_visibilities returns one entry per visibility group' do
      result = grouped_concept_scheme_visibilities(struct_double(id: 'cs-1'))

      assert_kind_of Array, result
      assert result.first.key?(:key)
    end

    test 'get_classifications_for_name finds a tree label by name' do
      assert_nil get_classifications_for_name('')
      assert_equal 'Inhaltstypen', get_classifications_for_name('Inhaltstypen').name
    end

    test 'get_classifications_for_id loads aliases with and without a tree filter' do
      alias_id = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').first.id

      get_classifications_for_id([alias_id])

      assert_includes @selected_classifications.map(&:id), alias_id

      get_classifications_for_id([alias_id], 'Inhaltstypen')

      assert_kind_of Enumerable, @selected_classifications
    end

    test 'get_classifications_for_id rescues lookup errors and returns nil' do
      assert_nil get_classifications_for_id(['00000000-0000-0000-0000-000000000000'])
    end

    test 'async_classification_select_options builds options from classification aliases' do
      ca = DataCycleCore::ClassificationAlias.for_tree('Inhaltstypen').first

      html = async_classification_select_options([ca])

      assert_includes html, ca.internal_name
    end

    test 'group_key_for_ctl matches an external system by name similarity' do
      es = { 'x' => struct_double(name: 'Feratel', identifier: 'feratel') }
      ctl = struct_double(external_source_id: nil, name: 'Feratel Tirol')

      assert_equal 'Feratel', group_key_for_ctl(ctl, es)
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
