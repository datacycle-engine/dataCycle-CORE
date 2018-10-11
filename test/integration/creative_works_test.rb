# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorksTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'create Artikel' do
      name = "test_artikel_#{Time.now.getutc.to_i}"
      post creative_works_path, params: {
        creative_work: {
          datahash: {
            headline: name
          }
        },
        table: 'creative_works',
        template: 'Artikel',
        locale: 'de'
      }, headers: {
        referer: root_path
      }

      content = DataCycleCore::CreativeWork.find_by(headline: name)

      assert_redirected_to edit_creative_work_path(content)
      assert_equal 'Artikel wurde erfolgreich erstellt.', flash[:notice]
    end

    test 'create content inside container' do
      name = "test_artikel_#{Time.now.getutc.to_i}"
      parent = DataCycleCore::CreativeWork.find_by(headline: 'TestContainer')

      post creative_works_path, params: {
        creative_work: {
          datahash: {
            headline: name
          }
        },
        table: 'creative_works',
        template: 'Artikel',
        locale: 'de',
        parent_id: parent.id
      }

      child = DataCycleCore::CreativeWork.find_by(headline: name)

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
      content = DataCycleCore::CreativeWork.find_by(headline: 'TestArtikel')

      patch creative_work_path(content), params: {
        creative_work: {
          datahash: content.get_data_hash.merge('headline' => updated_name)
        }
      }, headers: {
        referer: edit_creative_work_path(content)
      }

      assert_redirected_to creative_work_path(content)
      assert_equal 'Artikel wurde aktualisiert.', flash[:success]
      follow_redirect!
      assert_select '.detail-header > .title', updated_name
    end

    test 'delete content' do
      content = DataCycleCore::CreativeWork.find_by(headline: 'TestArtikel')

      delete creative_work_path(content), params: {}, headers: {
        referer: creative_work_path(content)
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
      container = DataCycleCore::CreativeWork.find_by(headline: 'TestContainer')
      content = DataCycleCore::CreativeWork.find_by(headline: 'TestArtikel')
      content.is_part_of = container.id
      content.save!

      delete creative_work_path(container), params: {}, headers: {
        referer: creative_work_path(container)
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
