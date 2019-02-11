# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedObjectTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Zeitleiste', data_hash: { name: 'TestZeitleiste' })
      @person = DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: { given_name: 'Der', family_name: 'Tester' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'update content -> add multiple embedded objects (Zeitleiste-Eintrag)' do
      timeline_item = Array.new(6) { |i| { 'name' => "Zeitleiste-Eintrag #{i}" } }
      patch thing_path(@content), params: {
        thing: {
          datahash: @content.get_data_hash.merge({
            'timeline_item' => timeline_item
          })
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_redirected_to thing_path(@content, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language), flash[:success]
      follow_redirect!
      assert_equal 6, @content.reload.timeline_item.size
    end

    test 'update content -> update embedded object (Zeitleiste)' do
      content_with_timeline_item = DataCycleCore::TestPreparations.create_content(template_name: 'Zeitleiste', data_hash: {
        name: 'TestArtikelMitZeitleiste',
        timeline_item: [{
          'name': 'Zeitleiste 1'
        }]
      })

      assert content_with_timeline_item
      content_hash = content_with_timeline_item.get_data_hash
      content_hash['timeline_item'] = [
        content_hash['timeline_item'].first.merge({
          'name' => 'Updated Zeitleiste 1'
        })
      ]

      patch thing_path(content_with_timeline_item), params: {
        thing: {
          datahash: content_hash
        }
      }, headers: {
        referer: edit_thing_path(content_with_timeline_item)
      }

      assert_redirected_to thing_path(content_with_timeline_item, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: content_with_timeline_item.template_name, locale: DataCycleCore.ui_language), flash[:success]
      follow_redirect!
      assert_equal 'Updated Zeitleiste 1', content_with_timeline_item.reload.timeline_item.first.name
    end

    test 'render new embedded object (Zeitleiste in Artikel)' do
      get new_embedded_object_thing_path(@content), xhr: true, as: :json, params: {
        content_id: @content.id,
        content_type: @content.class.table_name,
        definition: @content.schema.dig('properties', 'timeline_item'),
        key: 'thing[datahash][timeline_item]',
        locale: 'de',
        index: 0,
        options: {
          readonly: false
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response :success
      assert @response.body.include?(@content.schema.dig('properties', 'timeline_item', 'label'))
    end

    test 'render existing embedded object (Zeitleiste in Artikel)' do
      timeline_item = DataCycleCore::Thing.find_by(template_name: 'Zeitleiste', template: true).dup
      timeline_item.template = false
      timeline_item.save!
      I18n.with_locale(:de) do
        timeline_item.set_data_hash(data_hash: { 'name' => 'Test Zeitleiste' }, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
      end

      assert timeline_item.reload

      get render_embedded_object_thing_path(@content), xhr: true, as: :json, params: {
        content_id: @content.id,
        content_type: @content.class.table_name,
        definition: @content.schema.dig('properties', 'timeline_item'),
        key: 'thing[datahash][timeline_item]',
        locale: 'de',
        index: 0,
        options: {
          readonly: false
        },
        object_ids: [
          timeline_item.id
        ]
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response :success
      assert @response.body.include?(timeline_item.name)
    end
  end
end
