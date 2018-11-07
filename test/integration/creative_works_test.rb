# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorksTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      @container = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: { name: 'TestContainer' })
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

      assert_redirected_to edit_polymorphic_path(content)
      assert_equal 'Artikel wurde erfolgreich erstellt.', flash[:notice]
    end

    test 'create content inside container' do
      name = "test_artikel_#{Time.now.getutc.to_i}"

      post things_path, params: {
        thing: {
          datahash: {
            name: name
          }
        },
        table: 'things',
        template: 'Artikel',
        locale: 'de',
        parent_id: @container.id
      }

      child = DataCycleCore::Thing.find_by(name: name)

      assert child
      assert_equal(child.parent.id, @container.id)
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

      patch polymorphic_path(@content), params: {
        thing: {
          datahash: @content.get_data_hash.merge('name' => updated_name)
        }
      }, headers: {
        referer: edit_polymorphic_path(@content)
      }

      assert_redirected_to polymorphic_path(@content)
      assert_equal 'Artikel wurde aktualisiert.', flash[:success]
      follow_redirect!
      assert_select '.detail-header > .title', updated_name
    end

    test 'delete content' do
      delete polymorphic_path(@content), params: {}, headers: {
        referer: polymorphic_path(@content)
      }

      assert_redirected_to root_path
      assert_equal 'Artikel wurde gelöscht.', flash[:success]

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

    test 'delete container with child' do
      @content.update({ is_part_of: @container.id })

      delete polymorphic_path(@container), params: {}, headers: {
        referer: polymorphic_path(@container)
      }

      assert_redirected_to root_path
      assert_equal 'Container wurde gelöscht.', flash[:success]

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

      get root_path, params: {
        utf8: '✓',
        f: {
          s: {
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => 'TestContainer'
          }
        },
        language: ['de']
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestContainer' }
    end
  end
end
