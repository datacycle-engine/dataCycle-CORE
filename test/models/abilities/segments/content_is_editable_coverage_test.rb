# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ContentIsEditable ability segment - the scope-keyword dispatch in
  # include? and the individual editability predicates, over a content double (Overlay is
  # stubbed so no feature config / database is needed).
  class ContentIsEditableSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ContentIsEditable

    def content_double(template_name: 'Artikel', global_property_names: ['x'])
      content = Object.new
      content.define_singleton_method(:template_name) { template_name }
      content.define_singleton_method(:global_property_names) { global_property_names }
      content.define_singleton_method(:external_source_id) { nil }
      content
    end

    test 'by_scope_and_template_name? is false for a blank scope and matches templates otherwise' do
      seg = Subject.new
      config = { 'edit' => ['Artikel'] }

      assert_not seg.by_scope_and_template_name?(content_double, config, scope: nil)
      assert seg.by_scope_and_template_name?(content_double(template_name: 'Artikel'), config, scope: 'edit')
    end

    test 'include? dispatches to a scope-keyword method' do
      seg = Subject.new([[:by_scope_and_template_name?, { 'edit' => ['Artikel'] }]])

      assert seg.include?(content_double(template_name: 'Artikel'), 'edit') # rubocop:disable Minitest/AssertIncludes
    end

    test 'content_overlay_allowed? and content_global_property_names_present? delegate to the content' do
      seg = Subject.new

      overlay_allowed = DataCycleCore::Feature::Overlay.stub(:allowed?, true) do
        seg.content_overlay_allowed?(content_double)
      end

      assert overlay_allowed
      assert seg.content_global_property_names_present?(content_double(global_property_names: ['name']))
    end
  end
end
