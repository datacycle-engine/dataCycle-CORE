# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class DuplicateEmbeddedTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers

      setup do
        @routes = Engine.routes
        @content = DataCycleCore::TestPreparations.create_content(
          template_name: 'Embedded-Entity-Creative-Work-1',
          data_hash: { 'name' => 'parent', 'embedded_creative_work' => [{ 'name' => 'block' }] }
        )
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      def render_embedded(content: @content, key: 'embedded_creative_work', status: :success, **params)
        post render_embedded_object_thing_path(content), xhr: true, as: :json, params: {
          content_id: content.id,
          content_type: content.class.table_name,
          definition: content.schema.dig('properties', key),
          key: "thing[datahash][#{key}]",
          locale: 'de',
          index: 3,
          options: { readonly: false }
        }.merge(params), headers: { referer: edit_thing_path(content) }

        assert_response status
        response.parsed_body
      end

      def field_value(fragment, name)
        fragment.css("input[name$=\"#{name}\"]").first['value']
      end

      test 'every embedded offers the copy button while the feature is enabled, new ones included' do
        get edit_thing_path(@content)

        assert_response :success
        assert_select ".content-object-item[data-id='#{@content.embedded_creative_work.first.id}'] .duplicate-embedded", 1

        new_item = Nokogiri::HTML.fragment(render_embedded(embedded_template: 'Embedded-Creative-Work-2')['html'])

        assert_equal 1, new_item.css('.duplicate-embedded').size

        DataCycleCore::Feature::DuplicateEmbedded.stub(:enabled?, false) do
          get edit_thing_path(@content)
        end

        assert_select '.duplicate-embedded', 0
      end

      # the copy is rendered from the form, so an unsaved edit of the source is what gets copied;
      # the payload is what EmbeddedObject#copySource posts: multi-value fields as arrays
      test 'a copy from form data carries the current field values and persists nothing' do
        place = DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: { 'name' => 'place' })
        copy = nil

        assert_no_difference -> { DataCycleCore::Thing.count } do
          copy = Nokogiri::HTML.fragment(render_embedded(
            duplicated_content: true,
            embedded_template: 'Embedded-Creative-Work-2',
            copy_data: { 'datahash' => { 'id' => @content.embedded_creative_work.first.id, 'template_name' => 'Embedded-Creative-Work-2', 'name' => 'Titel 2', 'linked_place' => ['', place.id] } }
          )['html'])
        end

        assert_equal 'Titel 2', field_value(copy, '[datahash][name]')
        assert_includes copy.css('.linked_place [data-objects]').first['data-objects'], place.id
        assert_empty copy.css('input[type="hidden"][name$="[id]"]')
        assert_equal 'block', @content.embedded_creative_work.first.reload.name
      end

      # nested items arrive as an array in the JSON body, not indexed as a form submit sends them
      test 'a copy keeps every nested item of the form, identical ones included' do
        content = DataCycleCore::TestPreparations.create_content(
          template_name: 'Embedded-With-Translations',
          data_hash: { 'name' => 'parent', 'embedded_creative_work' => [{ 'name' => 'block' }] }
        )

        copy = Nokogiri::HTML.fragment(render_embedded(
          content:,
          duplicated_content: true,
          embedded_template: 'Embedded-With-Translations-1',
          copy_data: {
            'datahash' => {
              'id' => content.embedded_creative_work.first.id,
              'template_name' => 'Embedded-With-Translations-1',
              'name' => 'block 2',
              'embedded_creative_work' => [
                { 'datahash' => { 'template_name' => 'Embedded-With-Translations-2', 'name' => 'twin' } },
                { 'datahash' => { 'template_name' => 'Embedded-With-Translations-2', 'name' => 'twin' } }
              ]
            }
          }
        )['html'])

        nested = copy.css('.content-object-item .content-object-item')

        assert_equal 'block 2', field_value(copy, '[3][datahash][name]')
        assert_equal(['twin', 'twin'], nested.map { |n| field_value(n, '[datahash][name]') })
        assert_equal 0, DataCycleCore::Thing.where(template_name: 'Embedded-With-Translations-2').count
      end

      test 'a copy the validation rejects answers with the errors instead of an empty item' do
        body = render_embedded(
          status: :unprocessable_content,
          duplicated_content: true,
          embedded_template: 'Embedded-Creative-Work-2',
          copy_data: { 'datahash' => { 'template_name' => 'Embedded-Creative-Work-2', 'linked_place' => { 'not' => 'an array' } } }
        )

        assert_nil body['html']
        assert_includes body['error'], 'UUID'
      end
    end
  end
end
