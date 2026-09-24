# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class ReusableEmbeddedIntegrationTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers

      setup do
        @routes = Engine.routes
        @parent = DataCycleCore::TestPreparations.create_content(
          template_name: 'Embedded-Entity-Reusable',
          data_hash: {
            'name' => 'reusable-parent',
            'embedded_creative_work' => [
              { 'template_name' => 'Embedded-Creative-Work-Reusable', 'name' => 'flagged block', 'reusable' => true },
              { 'template_name' => 'Embedded-Creative-Work-Reusable', 'name' => 'unflagged block' },
              { 'template_name' => 'Embedded-Creative-Work-2', 'name' => 'other template block' }
            ]
          }
        )
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      def browse_embedded(definition = @parent.schema.dig('properties', 'embedded_creative_work'), content_id: nil, excluded: [])
        post object_browser_show_path, xhr: true, as: :json, params: {
          content_id:,
          excluded:,
          definition:,
          editable: true,
          key: 'thing[datahash][embedded_creative_work]',
          locale: 'de',
          objects: [],
          options: { readonly: false },
          page: 1,
          per: 25
        }, headers: { referer: edit_thing_path(@parent) }

        assert_response :success
      end

      test 'object browser offers only flagged embedded of the allowed templates' do
        browse_embedded

        assert_includes @response.body, 'flagged block'
        assert_not_includes @response.body, 'unflagged block'
        assert_not_includes @response.body, 'other template block'
      end

      test 'object browser leaves out what the edited content already embeds' do
        browse_embedded(content_id: @parent.id)

        assert_not_includes @response.body, 'flagged block'

        other = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Reusable', data_hash: { 'name' => 'other parent' })
        browse_embedded(content_id: other.id)

        assert_includes @response.body, 'flagged block'

        # what the form holds unsaved arrives as `excluded` (EmbeddedObject writes it to data-excluded)
        block = @parent.embedded_creative_work.detect { |e| e.name == 'flagged block' }
        browse_embedded(content_id: other.id, excluded: [block.id])

        assert_not_includes @response.body, 'flagged block'
      end

      test 'object browser keeps the template restriction for embedded definitions' do
        browse_embedded(@parent.schema.dig('properties', 'embedded_creative_work').merge('template_name' => ['Embedded-Creative-Work-2']))

        assert_not_includes @response.body, 'flagged block'
      end

      test 'object browser offers no embedded while the feature is disabled' do
        DataCycleCore::Feature::ReusableEmbedded.stub(:enabled?, false) do
          browse_embedded
        end

        assert_not_includes @response.body, 'flagged block'
      end

      test 'a linked block is one record with two parents, shown with usage badge and copy button' do
        block = @parent.embedded_creative_work.detect { |e| e.name == 'flagged block' }
        second = DataCycleCore::TestPreparations.create_content(
          template_name: 'Embedded-Entity-Reusable',
          data_hash: { 'name' => 'second parent', 'embedded_creative_work' => [{ 'id' => block.id, 'template_name' => 'Embedded-Creative-Work-Reusable' }] }
        )

        assert_equal [@parent.id, second.id].sort, block.content_a.pluck(:id).sort

        get edit_thing_path(second)

        assert_response :success
        assert_select ".content-object-item[data-id='#{block.id}'] .reusable-embedded-badge", text: '2'
        assert_select ".content-object-item[data-id='#{block.id}'] .unlink-embedded", 1

        unflagged = @parent.embedded_creative_work.detect { |e| e.name == 'unflagged block' }
        get edit_thing_path(@parent)

        assert_select ".content-object-item[data-id='#{block.id}'] .reusable-embedded-badge", text: '2'
        assert_select ".content-object-item[data-id='#{unflagged.id}'] .reusable-embedded-badge", 0
        assert_select ".content-object-item[data-id='#{unflagged.id}'] .unlink-embedded", 0

        # the flag removed, the block stays shared: badge and unlink button stay
        block.set_data_hash(data_hash: { 'reusable' => false })
        get edit_thing_path(@parent)

        assert_select ".content-object-item[data-id='#{block.id}'] .reusable-embedded-badge", text: '2'
        assert_select ".content-object-item[data-id='#{block.id}'] .unlink-embedded", 1
      end

      test 'a copy of a flagged block is rendered without the flag' do
        block = @parent.embedded_creative_work.detect { |e| e.name == 'flagged block' }

        post render_embedded_object_thing_path(@parent), xhr: true, as: :json, params: {
          content_id: @parent.id,
          content_type: @parent.class.table_name,
          definition: @parent.schema.dig('properties', 'embedded_creative_work'),
          key: 'thing[datahash][embedded_creative_work]',
          locale: 'de',
          index: 5,
          object_ids: [block.id],
          duplicated_content: true,
          options: { readonly: false }
        }, headers: { referer: edit_thing_path(@parent) }

        assert_response :success
        html = Nokogiri::HTML.fragment(response.parsed_body['html'])

        assert_equal 1, html.css('input[type="checkbox"][name$="[reusable]"]').size
        assert_empty html.css('input[type="checkbox"][name$="[reusable]"][checked]')
        assert_empty html.css('input[type="hidden"][name$="[id]"]')
        assert_predicate block.reload, :reusable?
      end

      # the same rule duplicate_data_hash applies to a page duplicate: a flagged block inside the
      # copied one is linked, everything else is copied
      test 'a copy keeps a nested flagged block as a link' do
        block = @parent.embedded_creative_work.detect { |e| e.name == 'flagged block' }
        hashes = @parent.embedded_creative_work.map do |e|
          hash = { 'id' => e.id, 'template_name' => e.template_name }
          e.id == block.id ? hash.merge('nested_creative_work' => [{ 'name' => 'nested flagged', 'reusable' => true }, { 'name' => 'nested plain' }]) : hash
        end
        @parent.set_data_hash(data_hash: { 'embedded_creative_work' => hashes })
        nested_flagged, nested_plain = block.reload.nested_creative_work.to_a

        post render_embedded_object_thing_path(@parent), xhr: true, as: :json, params: {
          content_id: @parent.id,
          content_type: @parent.class.table_name,
          definition: @parent.schema.dig('properties', 'embedded_creative_work'),
          key: 'thing[datahash][embedded_creative_work]',
          locale: 'de',
          index: 7,
          object_ids: [block.id],
          duplicated_content: true,
          options: { readonly: false }
        }, headers: { referer: edit_thing_path(@parent) }

        assert_response :success
        ids = Nokogiri::HTML.fragment(response.parsed_body['html']).css('input[type="hidden"][name$="[id]"]').pluck('value')

        assert_equal [nested_flagged.id], ids
        assert_not_includes ids, nested_plain.id
      end

      test 'edit form offers linking in the plus dropdown while the feature is enabled' do
        get edit_thing_path(@parent)

        assert_response :success
        assert_select '.new-embedded-object-links .select-existing-embedded', 1
        assert_select '.new-embedded-object-links .divider', 1
        assert_select '.reusable-embedded-browser[data-definition*="Embedded-Creative-Work-Reusable"]', 1

        plain = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-Creative-Work-1', data_hash: { 'name' => 'plain' })
        get edit_thing_path(plain)

        assert_response :success
        assert_select '.new-embedded-object-links .select-existing-embedded', 1

        DataCycleCore::Feature::ReusableEmbedded.stub(:enabled?, false) do
          get edit_thing_path(plain)
        end

        assert_select '.select-existing-embedded', 0
        assert_select '.new-embedded-object-links', 0
      end
    end
  end
end
