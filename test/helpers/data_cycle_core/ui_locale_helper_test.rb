# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class UiLocaleHelperTest < ActionView::TestCase
    include DataCycleCore::UiLocaleHelper

    # attribute_type_icon -> attribute_type_tooltip guard the internal name behind can?
    def can?(*) = false

    # active_ui_locale reads current_user; define it so it can be stubbed per test.
    def current_user = nil

    # api_definition comes from ApiHelper in real views; empty definitions enable the api name path.
    def api_definition(*) = {}

    test 'active_ui_locale falls back to the first configured ui locale' do
      assert_equal DataCycleCore.ui_locales.first, active_ui_locale
    end

    test 'active_ui_locale uses the current users ui_locale when available' do
      stub(:current_user, struct_double(ui_locale: :en)) do
        assert_equal :en, active_ui_locale
      end
    end

    test 'i18n_digest returns a digest string for the active locale' do
      assert_kind_of String, i18n_digest
    end

    test 'available_locales_with_names maps each available locale to a capitalized name' do
      result = available_locales_with_names

      assert_kind_of Hash, result
      assert result.key?(:de)
      assert result.key?(:en)
      assert(result.values.all?(String))
    end

    test 'available_locales_with_all adds an all entry when several locales are available' do
      assert available_locales_with_all.key?(:all)
    end

    test 'content_score_tooltip_string_helper converts html markup to plain text' do
      # the helper mutates its argument in place, so pass an unfrozen string
      input = +'<ul><li>First</li><li>Second</li></ul><p>para</p><br><div>d</div><b>bold</b>'

      assert_equal "* First\n* Second\npara\n\nd\nbold", content_score_tooltip_string_helper(input)
    end

    test 'attribute_translatable? delegates to the content and is nil without content' do
      content = Object.new
      def content.attribute_translatable?(key, _definition) = key == 'name'

      assert attribute_translatable?('name', {}, content)
      assert_not attribute_translatable?('other', {}, content)
      assert_nil attribute_translatable?('name', {}, nil)
    end

    test 'object_has_translatable_attributes? is false unless the definition is an object' do
      assert_not object_has_translatable_attributes?(Object.new, { 'type' => 'string' })
      assert_not object_has_translatable_attributes?(Object.new, nil)
    end

    test 'object_has_translatable_attributes? checks the object properties' do
      content = Object.new
      def content.attribute_translatable?(key, _definition) = key == 'name'
      definition = { 'type' => 'object', 'properties' => { 'name' => {}, 'age' => {} } }

      assert object_has_translatable_attributes?(content, definition)
    end

    test 'thing_content_score_class is set only for scored content' do
      scored = Object.new
      def scored.internal_content_score = 42

      assert_equal 'dc-content-score', thing_content_score_class(scored)
      assert_nil thing_content_score_class(Object.new)
    end

    test 'thing_helper_text and thing_info_icon are nil for non Thing content' do
      assert_nil thing_helper_text(Object.new, 'name')
      assert_nil thing_info_icon(Object.new, 'name')
    end

    test 'attribute_type_icon builds an icon with type and key classes' do
      definition = { 'type' => 'string', 'ui' => { 'show' => { 'type' => 'date' } } }
      html = attribute_type_icon(Object.new, 'name', definition)

      assert_includes html, 'dc-type-icon'
      assert_includes html, 'key-name'
      assert_includes html, 'type-string'
      assert_includes html, 'type-string-date'
    end

    test 'attribute_type_tooltip labels the api name even without internal name permission' do
      content = Object.new
      def content.api_name_for(_path, _definition) = 'dc:name'

      tooltip = attribute_type_tooltip(content, 'name', {})

      assert_includes tooltip, "<b>#{t('common.api_identifier', locale: active_ui_locale)}:</b>"
      assert_includes tooltip, 'dc:name'
      # the internal identifier stays hidden because can? is stubbed to false
      assert_not_includes tooltip, t('common.internal_identifier', locale: active_ui_locale)
    end

    test 'attribute_type_tooltip is nil without an api name or internal name permission' do
      assert_nil attribute_type_tooltip(Object.new, 'name', {})
    end

    test 'collection_model_name_human builds a localized placeholder label' do
      assert_kind_of String, collection_model_name_human
      assert_predicate collection_model_name_human, :present?
    end
  end
end
