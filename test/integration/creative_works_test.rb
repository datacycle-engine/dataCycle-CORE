# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorksTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'create Artikel' do
      name = "test_artikel_#{Time.now.getutc.to_i}"
      post things_path, params: {
        thing: {
          datahash: {
            name: name
          }
        },
        table: 'things',
        template: 'Artikel',
        locale: 'de'
      }, headers: {
        referer: root_path
      }

      content = DataCycleCore::Thing.find_by(name: name)

      assert_redirected_to edit_thing_path(content)
      assert_equal I18n.t(:created, scope: [:controllers, :success], data: content.template_name, locale: DataCycleCore.ui_language), flash[:notice]
    end

    test 'search content by fulltext' do
      get root_path, params: {
        utf8: '✓',
        f: {
          s: {
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => 'TestArtikel'
          }
        },
        language: ['de']
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'
    end

    test 'update content' do
      updated_name = "updated_test_artikel_#{Time.now.getutc.to_i}"

      patch thing_path(@content), params: {
        thing: {
          datahash: @content.get_data_hash.merge('name' => updated_name)
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_redirected_to thing_path(@content, locale: I18n.locale)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language), flash[:success]
      follow_redirect!
      assert_select '.detail-header > .title', updated_name
    end

    test 'show content history' do
      get thing_path(@content)
      assert_response :success
      assert_select '.detail-header > .title', @content.title

      get history_thing_path(@content, history_id: @content.histories&.first&.id)
      assert_response :success
      assert_select('.detail-content .type.properties .has-changes', count: 1)
    end

    test 'delete content' do
      delete thing_path(@content), params: {}, headers: {
        referer: thing_path(@content)
      }

      assert_redirected_to root_path
      assert_equal I18n.t(:destroyed, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language), flash[:success]

      get root_path, params: {
        utf8: '✓',
        f: {
          s: {
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => 'TestArtikel'
          }
        },
        language: ['de']
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestArtikel' }
    end
  end
end
