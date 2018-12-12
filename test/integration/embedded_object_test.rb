# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedObjectTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      @person = DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: { given_name: 'Der', family_name: 'Tester' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'update content -> add multiple embedded objects (Zitat)' do
      quotations = Array.new(6) { |i| { 'text' => "Quotation #{i}" } }
      patch thing_path(@content), params: {
        thing: {
          datahash: @content.get_data_hash.merge({
            'quotation' => quotations
          })
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_redirected_to thing_path(@content, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language), flash[:success]
      follow_redirect!
      assert_equal 6, @content.reload.quotation.size
    end

    test 'update content -> update embedded object (Zitat)' do
      content_with_quotation = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: {
        name: 'TestArtikelMitZitat',
        quotation: [{
          'text': 'Zitat 1'
        }]
      })

      assert content_with_quotation
      content_hash = content_with_quotation.get_data_hash
      content_hash['quotation'] = [
        content_hash['quotation'].first.merge({
          'text' => 'Updated Zitat 1'
        })
      ]

      patch thing_path(content_with_quotation), params: {
        thing: {
          datahash: content_hash
        }
      }, headers: {
        referer: edit_thing_path(content_with_quotation)
      }

      assert_redirected_to thing_path(content_with_quotation, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: content_with_quotation.template_name, locale: DataCycleCore.ui_language), flash[:success]
      follow_redirect!
      assert_equal 'Updated Zitat 1', content_with_quotation.reload.quotation.first.text
    end

    test 'render new embedded object (Zitat in Artikel)' do
      get new_embedded_object_thing_path(@content), xhr: true, as: :json, params: {
        content_id: @content.id,
        content_type: @content.class.table_name,
        definition: @content.schema.dig('properties', 'quotation'),
        key: 'thing[datahash][quotation]',
        locale: 'de',
        index: 0,
        options: {
          readonly: false
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response :success
      assert @response.body.include?(@content.schema.dig('properties', 'quotation', 'label'))
    end

    test 'render existing embedded object (Zitat in Artikel)' do
      quotation = DataCycleCore::Thing.find_by(template_name: 'Zitat', template: true).dup
      quotation.template = false
      quotation.save!
      I18n.with_locale(:de) do
        quotation.set_data_hash(data_hash: { 'text' => 'Test Zitat' }, new_content: true, current_user: User.find_by(email: 'tester@datacycle.at'))
      end

      assert quotation.reload

      get render_embedded_object_thing_path(@content), xhr: true, as: :json, params: {
        content_id: @content.id,
        content_type: @content.class.table_name,
        definition: @content.schema.dig('properties', 'quotation'),
        key: 'thing[datahash][quotation]',
        locale: 'de',
        index: 0,
        options: {
          readonly: false
        },
        object_ids: [
          quotation.id
        ]
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response :success
      assert @response.body.include?(quotation.text)
    end
  end
end
