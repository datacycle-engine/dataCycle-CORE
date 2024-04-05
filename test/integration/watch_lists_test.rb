# frozen_string_literal: true

require 'test_helper'
require_relative '../../app/helpers/data_cycle_core/bulk_edit_helper'
require_relative '../../app/helpers/data_cycle_core/application_helper'

module DataCycleCore
  class WatchListsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    include DataCycleCore::BulkEditHelper
    include DataCycleCore::ApplicationHelper

    before(:all) do
      @routes = Engine.routes
      @default_tags = DataCycleCore::Classification.for_tree('Tags').where(name: ['Tag 1', 'Tag 2']).ids
      @additional_tags = DataCycleCore::Classification.for_tree('Ausgabekanäle').where(name: 'Tag 3').ids
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel', tags: @default_tags })
      @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
      @current_user = User.find_by(email: 'tester@datacycle.at')
      @organization = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'TestOrganisation' })
      @image_a = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'TestBildA', author: [@organization.id] })
      @image_b = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'TestBildB', author: [@organization.id] })
      @image_c = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'TestBildC', copyright_holder: [@organization.id] })
    end

    setup do
      sign_in(@current_user)
    end

    test 'create Watchlist' do
      name = "test_watch_list_#{Time.now.getutc.to_i}"

      post watch_lists_path, xhr: true, params: {
        watch_list: {
          full_path: name
        }
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal DataCycleCore::WatchList.where(name:).size, 1

      get api_v2_collections_path
      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert_equal(1, json_data.dig('collections').count { |w| w['name'] == name })
    end

    test 'update Watchlist' do
      user_group = DataCycleCore::UserGroup.find_by(name: 'TestUserGroup')
      name = "test_watch_list_#{Time.now.getutc.to_i}"

      patch watch_list_path(id: @watch_list), params: {
        watch_list: {
          full_path: name,
          user_group_ids: [user_group.id]
        }
      }, headers: {
        referer: edit_watch_list_path(@watch_list)
      }

      assert_redirected_to watch_list_path(@watch_list)
      assert_equal I18n.t(:updated, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_locales.first), locale: DataCycleCore.ui_locales.first), flash[:success]
      follow_redirect!
      assert_equal @watch_list.reload.name, name
    end

    test 'validate Watchlist' do
      name = "test_watch_list_#{Time.now.getutc.to_i}"

      post validate_watch_list_path(id: @watch_list), params: {
        watch_list: {
          full_path: name
        }
      }, headers: {
        referer: edit_watch_list_path(@watch_list)
      }

      assert_response :success
      response_body = response.parsed_body
      assert response_body['valid']
    end

    test 'validate Watchlist with empty name' do
      post validate_watch_list_path(id: @watch_list), params: {
        watch_list: {
          full_path: nil
        }
      }, headers: {
        referer: edit_watch_list_path(@watch_list)
      }

      assert_response :success
      response_body = response.parsed_body
      assert_not response_body['valid']
    end

    test 'delete Watchlist' do
      delete watch_list_path(@watch_list), params: {}, headers: {
        referer: watch_list_path(@watch_list)
      }

      assert_redirected_to root_path
      assert_equal I18n.t(:destroyed, scope: [:controllers, :success], data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_locales.first), locale: DataCycleCore.ui_locales.first), flash[:success]

      get api_v2_collections_path
      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert_equal json_data.dig('collections').size, 0
    end

    test 'add content to watch_list' do
      get add_item_watch_list_path(@watch_list), xhr: true, params: {
        hashable_id: @content.id,
        hashable_type: @content.class.name
      }, headers: {
        referer: root_path
      }

      assert_response :success

      get watch_list_path(@watch_list)
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'

      get api_v2_collection_path(@watch_list)
      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert_equal json_data.dig('collection', 'items').size, 1
    end

    test 'add related content to watch_list' do
      post add_related_items_watch_lists_path, xhr: true, params: {
        watch_list_id: @watch_list.id,
        template_name: 'Bild',
        relation_a: 'author',
        content_id: @organization.id
      }, headers: {
        referer: root_path
      }

      assert_response :success
      assert_equal DataCycleCore::WatchList.where(name: @watch_list.name).size, 1
      assert @watch_list.things.ids.include?(@image_a.id)
      assert @watch_list.things.ids.include?(@image_b.id)
      assert_not @watch_list.things.ids.include?(@image_c.id)

      get watch_list_path(@watch_list)
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestBildB'

      get api_v2_collection_path(@watch_list)
      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert_equal json_data.dig('collection', 'items').size, 2
    end

    test 'add related content to new watch_list' do
      post add_related_items_watch_lists_path, xhr: true, params: {
        watch_list_id: 'TestWatchList2',
        template_name: 'Bild',
        relation_a: 'author',
        content_id: @organization.id
      }, headers: {
        referer: root_path
      }

      assert_response :success
      watch_list = DataCycleCore::WatchList.find_by(name: 'TestWatchList2')
      assert_not_nil watch_list

      assert watch_list.things.ids.include?(@image_a.id)
      assert watch_list.things.ids.include?(@image_b.id)
      assert_not watch_list.things.ids.include?(@image_c.id)

      get watch_list_path(watch_list)
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestBildB'

      get api_v2_collection_path(watch_list)
      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert_equal json_data.dig('collection', 'items').size, 2
    end

    test 'remove content from watch_list' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)

      delete remove_item_watch_list_path(@watch_list), xhr: true, params: {
        hashable_id: @content.id,
        hashable_type: @content.class.name
      }, headers: {
        referer: root_path
      }

      assert_response :success

      get watch_list_path(@watch_list)
      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestArtikel' }

      get api_v2_collection_path(@watch_list)
      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert_equal json_data.dig('collection', 'items').size, 0
    end

    test 'bulk delete all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      items_before = @watch_list.things.count

      delete bulk_delete_watch_list_path(@watch_list), params: {}, headers: { referer: watch_list_path(@watch_list) }
      assert_response :success

      items_after = @watch_list.things.count
      assert_equal(0, items_after)
      assert(items_before != items_after)
    end

    test 'bulk delete all watch_list_items, fails because one item is external' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      content2.external_source_id = ExternalSystem.first.id
      content2.save!
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: content2.id, hashable_type: content2.class.name)
      items_before = @watch_list.things.count

      delete bulk_delete_watch_list_path(@watch_list), params: {}, headers: { referer: watch_list_path(@watch_list) }
      assert_response :success

      assert_equal(items_before, @watch_list.things.count)
    end

    test 'bulk edit all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      shared_ordered_properties = @watch_list.things.shared_ordered_properties(@current_user).keys

      get bulk_edit_watch_list_path(@watch_list), params: {}, headers: {
        referer: watch_list_path(@watch_list)
      }

      assert_response :success

      shared_ordered_properties.except('release_status_id').each do |property|
        assert_select ".form-element.#{property}"
      end
    end

    test 'bulk update all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      bulk_name = 'Test Artikel Bulk Update 1'
      content_template = to_query_params(thing_template: generic_content(@watch_list).thing_template).to_json

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'de',
        thing: {
          translations: {
            de: {
              name: bulk_name
            }
          }
        },
        bulk_update: {
          translations: {
            de: {
              name: ['override']
            }
          }
        },
        content_template:
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal I18n.t(:bulk_updated, scope: [:controllers, :success], count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal bulk_name, @content.name

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'de',
        thing: {
          translations: {
            en: {
              name: 'New Test Artikel not Bulk Updated'
            }
          }
        },
        bulk_update: {
          translations: {
            en: {
              name: ['override']
            }
          }
        },
        content_template:
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal I18n.t(:bulk_updated, scope: [:controllers, :success], count: 1, locale: DataCycleCore.ui_locales.first) + I18n.t(:bulk_updated_skipped_html, scope: [:controllers, :info], counts: 'en: <b>1</b>', locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal bulk_name, @content.name
    end

    test 'bulk update all watch_list items - override classifications' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      bulk_name = 'Test Artikel Bulk Update 1'

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'de',
        thing: {
          datahash: {
            tags: @additional_tags
          },
          translations: {
            de: {
              name: bulk_name
            }
          }
        },
        bulk_update: {
          datahash: {
            tags: ['override']
          },
          translations: {
            de: {
              name: ['override']
            }
          }
        },
        content_template: to_query_params(thing_template: generic_content(@watch_list).thing_template).to_json
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal I18n.t(:bulk_updated, scope: [:controllers, :success], count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal @additional_tags.to_set, @content.tags.reload.ids.to_set
    end

    test 'bulk update all watch_list items - add classifications' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      bulk_name = 'Test Artikel Bulk Update 1'

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'de',
        thing: {
          datahash: {
            tags: @additional_tags
          },
          translations: {
            de: {
              name: bulk_name
            }
          }
        },
        bulk_update: {
          datahash: {
            tags: ['add']
          },
          translations: {
            de: {
              name: ['override']
            }
          }
        },
        content_template: to_query_params(thing_template: generic_content(@watch_list).thing_template).to_json
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal I18n.t(:bulk_updated, scope: [:controllers, :success], count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal (@default_tags + @additional_tags).to_set, @content.tags.reload.ids.to_set
    end

    test 'bulk update all watch_list items - remove classification' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      bulk_name = 'Test Artikel Bulk Update 1'

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'de',
        thing: {
          datahash: {
            tags: [@default_tags.first]
          },
          translations: {
            de: {
              name: bulk_name
            }
          }
        },
        bulk_update: {
          translations: {
            de: {
              name: ['override']
            }
          },
          datahash: {
            tags: ['remove']
          }
        },
        content_template: to_query_params(thing_template: generic_content(@watch_list).thing_template).to_json
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal I18n.t(:bulk_updated, scope: [:controllers, :success], count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal [@default_tags.last].to_set, @content.tags.reload.ids.to_set
    end

    test 'validate (bulk update) watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)
      bulk_name = 'Test Artikel Bulk Update 1'

      post validate_watch_list_path(@watch_list), xhr: true, params: {
        thing: {
          datahash: {
            name: bulk_name
          }
        },
        bulk_update: {
          name: ['override']
        },
        content_template: to_query_params(thing_template: generic_content(@watch_list).thing_template).to_json
      }, headers: {
        referer: bulk_edit_watch_list_path(@watch_list)
      }

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body
      assert json_data['valid']
    end

    test 'add search items to watch_list' do
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Zweiter Inhalt' })
      @watch_list.things << content2

      assert @watch_list.things.ids.include?(content2.id)

      post add_to_watchlist_stored_filters_path, params: {
        f: {
          s: {
            n: 'Suchbegriff',
            t: 'fulltext_search',
            v: @content.title
          }
        },
        watch_list_id: @watch_list.id
      }, headers: {
        referer: root_path
      }

      assert_redirected_to root_path
      assert_equal I18n.t('controllers.success.added_to', data: @watch_list.name, type: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_locales.first), locale: DataCycleCore.ui_locales.first), flash[:notice]
      assert @watch_list.things.ids.include?(@content.id)
      assert @watch_list.things.ids.include?(content2.id)
    end

    test 'clear watch_list' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @content.id, hashable_type: @content.class.name)

      assert_equal(1, @watch_list.things.count)

      delete clear_watch_list_path(@watch_list), params: {}, headers: { referer: watch_list_path(@watch_list) }
      assert_redirected_to watch_list_path(@watch_list)

      assert_equal(0, @watch_list.things.count)
    end
  end
end
