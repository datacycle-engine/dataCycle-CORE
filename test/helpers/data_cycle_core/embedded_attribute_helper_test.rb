# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedAttributeHelperTest < ActionView::TestCase
    include DataCycleCore::EmbeddedAttributeHelper
    include DataCycleCore::ApplicationHelper

    def current_user = nil
    def contextual_content(_local_assigns) = @ctx_content
    def active_ui_locale = :de

    test 'embedded_viewer_html_classes returns the static wrapper classes' do
      assert_equal 'detail-type embedded-viewer embedded-wrapper', embedded_viewer_html_classes
      assert_equal 'detail-type embedded-viewer embedded-wrapper', embedded_viewer_html_classes(key: 'anything')
    end

    test 'parsed_allowed_locales defaults to all available locales' do
      assert_equal I18n.available_locales, parsed_allowed_locales
      assert_equal I18n.available_locales, parsed_allowed_locales({})
    end

    test 'parsed_allowed_locales uses the configured allowed locales when present' do
      assert_equal [:de], parsed_allowed_locales({ parameters: { allowed_locales: ['de'] } })
    end

    test 'force_render_locales_for_key returns the explicit override or the object locales' do
      assert_equal [:de], force_render_locales_for_key(nil, { force_render_locales: [:de] })

      @ctx_content = Object.new
      def @ctx_content.translatable_property?(_key) = false

      assert_equal [:de, :en], force_render_locales_for_key(struct_double(available_locales: [:de, :en]), { key: struct_double(attribute_name_from_key: 'foo') })
    end

    test 'allowed_embedded_locales_for_key returns configured or available locales for a non-translatable key' do
      @ctx_content = Object.new
      def @ctx_content.translatable_property?(_key) = false

      assert_equal [:de], allowed_embedded_locales_for_key({ key: struct_double(attribute_name_from_key: 'foo'), allowed_locales: ['de'] })
      assert_equal I18n.available_locales, allowed_embedded_locales_for_key({ key: struct_double(attribute_name_from_key: 'foo') })
    end

    test 'allowed_embedded_locales_for_key returns the current locale for a translatable key' do
      @ctx_content = Object.new
      def @ctx_content.translatable_property?(_key) = true

      assert_equal [I18n.locale], allowed_embedded_locales_for_key({ key: struct_double(attribute_name_from_key: 'foo') })
    end

    test 'embedded_templates_for_select orders the options by their translated name' do
      labels = { 'Quote' => 'Zitate', 'Enumeration' => 'Aufzählung', 'OpeningHours' => 'Öffnungszeiten', 'Accordion' => 'Accordion' }
      templates = labels.transform_values do |label|
        Object.new.tap { |t| t.define_singleton_method(:translated_template_name) { |_locale| label } }
      end

      DataCycleCore::DataHashService.stub(:get_internal_template, ->(name) { templates[name] }) do
        result = embedded_templates_for_select(labels.keys).map { |t| t.translated_template_name(:de) }

        # Öffnungszeiten before Zitate only holds because the sort transliterates
        assert_equal ['Accordion', 'Aufzählung', 'Öffnungszeiten', 'Zitate'], result
      end
    end

    test 'embedded_attribute_value returns the translated text when translation is allowed' do
      object = Object.new
      def object.new_record? = false
      def object.generic_template? = true
      def object.try(_key) = 'original'
      def object.first_available_locale = :de

      translate_feature = Object.new
      def translate_feature.allowed?(*_args) = true
      def translate_feature.translate_text(_hash) = { 'text' => 'translated' }

      DataCycleCore::Feature.stub(:[], translate_feature) do
        result = embedded_attribute_value(nil, object, struct_double(attribute_name_from_key: 'name', to_sym: :name), { 'type' => 'string' }, :en, true)

        assert_equal 'translated', result
      end
    end
  end
end
