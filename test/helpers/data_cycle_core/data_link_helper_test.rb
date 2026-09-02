# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DataLinkHelperTest < ActionView::TestCase
    include DataCycleCore::DataLinkHelper
    include DataCycleCore::UiLocaleHelper

    def current_user = nil

    test 'finalize_agbs_label renders a finalize span when there is no agbs translation' do
      html = finalize_agbs_label

      assert_includes html, 'Bearbeitung final abschließen'
      assert_includes html, 'data-dc-tooltip'
      assert_predicate html, :html_safe?
    end

    test 'terms_of_use_label returns html-safe content' do
      html = terms_of_use_label

      assert_predicate html, :html_safe?
      assert_predicate html, :present?
    end

    test 'download_item_type renders the type and title for a non-thing item' do
      data_link = struct_double(item: DataCycleCore::WatchList.new(name: 'My List'))
      html = download_item_type(data_link)

      assert_includes html, 'My List'
      assert_includes html, 'item-title'
    end

    test 'data_link_modes maps the allowed permissions to structs' do
      DataCycleCore::DataLink.stub(:allowed_permissions, [:read, :write]) do
        modes = data_link_modes(Object.new)

        assert_equal [:read, :write], modes.map(&:type)
      end
    end

    test 'finalize_agbs_label renders the combined label when an agbs translation exists' do
      I18n.stub(:exists?, true) do
        html = finalize_agbs_label

        assert_predicate html, :present?
        assert_predicate html, :html_safe?
      end
    end

    test 'terms_of_use_label links to a configured terms of use url' do
      config = { 'confirmation' => { 'terms_of_use_url' => 'https://example.com/terms' } }

      DataCycleCore::Feature::Download.stub(:configuration, config) do
        html = terms_of_use_label

        assert_includes html.to_s, 'https://example.com/terms'
      end
    end

    test 'download_item_type renders the template name and title for a thing item' do
      thing = DataCycleCore::Thing.new(template_name: DataCycleCore::ThingTemplate.first.template_name)
      thing.define_singleton_method(:first_available_locale) { :de }
      thing.define_singleton_method(:title) { 'Thing Title' }

      html = download_item_type(struct_double(item: thing))

      assert_includes html, 'Thing Title'
      assert_includes html, 'item-title'
    end
  end
end
