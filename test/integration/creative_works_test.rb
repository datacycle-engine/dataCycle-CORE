# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorksTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      DataCycleCore::TestPreparations.create_contents
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
      assert_equal 'Artikel wurde erfolgreich erstellt.', flash[:notice]
    end

    test 'create content inside container' do
      name = "test_artikel_#{Time.now.getutc.to_i}"
      parent = DataCycleCore::Thing.find_by(name: 'TestContainer')

      post things_path, params: {
        thing: {
          datahash: {
            name: name
          }
        },
        table: 'things',
        template: 'Artikel',
        locale: 'de',
        parent_id: parent.id
      }

      child = DataCycleCore::Thing.find_by(name: name)

      assert child
      assert_equal(child.parent.id, parent.id)
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
      content = DataCycleCore::Thing.find_by(name: 'TestArtikel')

      patch thing_path(content), params: {
        thing: {
          datahash: content.get_data_hash.merge('name' => updated_name)
        }
      }, headers: {
        referer: edit_thing_path(content)
      }

      assert_redirected_to thing_path(content)
      assert_equal 'Artikel wurde aktualisiert.', flash[:success]
      follow_redirect!
      assert_select '.detail-header > .title', updated_name
    end

    test 'delete content' do
      content = DataCycleCore::Thing.find_by(name: 'TestArtikel')

      delete thing_path(content), params: {}, headers: {
        referer: thing_path(content)
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
      container = DataCycleCore::Thing.find_by(name: 'TestContainer')
      content = DataCycleCore::Thing.find_by(name: 'TestArtikel')
      content.is_part_of = container.id
      content.save!

      delete thing_path(container), params: {}, headers: {
        referer: thing_path(container)
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
