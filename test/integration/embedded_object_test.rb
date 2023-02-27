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
      timeline_item = Array.new(6) { |i| { translations: { de: { 'name' => "Zeitleiste-Eintrag #{i}" } } } }
      patch thing_path(@content), params: {
        thing: {
          datahash: {
            'timeline_item' => timeline_item
          }
        },
        save_and_close: true
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_redirected_to thing_path(@content, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_equal 6, @content.timeline_item.reload.size
    end

    test 'update content -> update embedded object (Zeitleiste)' do
      content_with_timeline_item = DataCycleCore::TestPreparations.create_content(template_name: 'Zeitleiste', data_hash: {
        name: 'TestArtikelMitZeitleiste',
        timeline_item: [{
          'name': 'Zeitleiste 1'
        }]
      })

      assert content_with_timeline_item
      content_hash = {
        timeline_item: [
          {
            datahash: {
              id: content_with_timeline_item.timeline_item.first.id
            },
            translations: {
              de: {
                name: 'Updated Zeitleiste 1'
              }
            }
          }
        ]
      }

      patch thing_path(content_with_timeline_item), params: {
        thing: {
          datahash: content_hash
        },
        save_and_close: true
      }, headers: {
        referer: edit_thing_path(content_with_timeline_item)
      }

      assert_redirected_to thing_path(content_with_timeline_item, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: content_with_timeline_item.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_equal 'Updated Zeitleiste 1', content_with_timeline_item.timeline_item.reload.first.name
    end

    test 'render new embedded object (Zeitleiste in Artikel)' do
      post render_embedded_object_thing_path(@content), xhr: true, as: :json, params: {
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

      post render_embedded_object_thing_path(@content), xhr: true, as: :json, params: {
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
        ],
        duplicated_content: true
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response :success
      assert @response.body.include?(timeline_item.name)
    end

    test 'update content -> update nested embedded' do
      content_with_nested_item = DataCycleCore::TestPreparations.create_content(template_name: 'Service', data_hash: {
        name: 'Service mit nested embedded',
        offers: [{
          name: 'Offer 1',
          price_specification: [{
            price: 12.839,
            unit_text: 'test'
          }]
        }]
      })

      content_hash = content_with_nested_item.get_data_hash

      assert content_hash.dig('offers', 0, 'price_specification', 0, 'id').present?

      update_hash = {
        offers: [{
          datahash: {
            id: content_hash.dig('offers', 0, 'id'),
            price_specification: [{
              datahash: {
                id: content_hash.dig('offers', 0, 'price_specification', 0, 'id'),
                unit_text: ''
              }
            }]
          }
        }]
      }

      patch thing_path(content_with_nested_item), params: {
        thing: {
          datahash: update_hash
        },
        save_and_close: true
      }, headers: {
        referer: edit_thing_path(content_with_nested_item)
      }

      assert_redirected_to thing_path(content_with_nested_item, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: content_with_nested_item.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_nil content_with_nested_item.reload.offers.reload.first.price_specification.reload.first.unit_text
    end
  end
end
