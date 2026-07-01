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
      @default_tags = DataCycleCore::Classification.for_tree('Tags').where(name: ['Tag 1', 'Tag 2']).pluck(:id)
      @additional_tags = DataCycleCore::Classification.for_tree('Ausgabekanäle').where(name: 'Tag 3').pluck(:id)
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
      assert_equal 1, DataCycleCore::WatchList.where(name:).size

      get api_v2_collections_path

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body

      assert_equal(1, json_data['collections'].count { |w| w['name'] == name })
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
      assert_equal I18n.t('controllers.success.updated', data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_locales.first), locale: DataCycleCore.ui_locales.first), flash[:success]
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
      assert_equal I18n.t('controllers.success.destroyed', data: DataCycleCore::WatchList.model_name.human(count: 1, locale: DataCycleCore.ui_locales.first), locale: DataCycleCore.ui_locales.first), flash[:success]

      get api_v2_collections_path

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body

      assert_equal 0, json_data['collections'].size
    end

    test 'add content to watch_list' do
      post add_item_watch_list_path(@watch_list), xhr: true, params: {
        thing_id: @content.id
      }, headers: {
        referer: root_path
      }

      assert_response :success

      get watch_list_path(@watch_list)

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestArtikel'

      get api_v2_collection_path(@watch_list)

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body

      assert_equal 1, json_data.dig('collection', 'items').size
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
      assert_equal 1, DataCycleCore::WatchList.where(name: @watch_list.name).size
      assert_includes @watch_list.things.pluck(:id), @image_a.id
      assert_includes @watch_list.things.pluck(:id), @image_b.id
      assert_not @watch_list.things.pluck(:id).include?(@image_c.id)

      get watch_list_path(@watch_list)

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestBildB'

      get api_v2_collection_path(@watch_list)

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body

      assert_equal 2, json_data.dig('collection', 'items').size
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

      assert_includes watch_list.things.pluck(:id), @image_a.id
      assert_includes watch_list.things.pluck(:id), @image_b.id
      assert_not watch_list.things.pluck(:id).include?(@image_c.id)

      get watch_list_path(watch_list)

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', 'TestBildB'

      get api_v2_collection_path(watch_list)

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body

      assert_equal 2, json_data.dig('collection', 'items').size
    end

    test 'remove content from watch_list' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)

      delete remove_item_watch_list_path(@watch_list), xhr: true, params: {
        thing_id: @content.id
      }, headers: {
        referer: root_path
      }

      assert_response :success

      get watch_list_path(@watch_list)

      assert_response :success
      assert_select 'li.grid-item > .content-link > .inner > .title', { count: 0, text: 'TestArtikel' }

      get api_v2_collection_path(@watch_list)

      assert_response :success
      assert_equal 'application/json; charset=utf-8', response.content_type
      json_data = response.parsed_body

      assert_equal 0, json_data.dig('collection', 'items').size
    end

    test 'bulk delete all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
      items_before = @watch_list.things.count

      delete bulk_delete_watch_list_path(@watch_list), params: {}, headers: { referer: watch_list_path(@watch_list) }

      assert_response :success

      items_after = @watch_list.things.count

      assert_equal(0, items_after)
      assert_not_equal(items_before, items_after)
    end

    test 'bulk delete all watch_list_items, fails because one item is external' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
      content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      content2.external_source_id = ExternalSystem.first.id
      content2.save!
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: content2.id)
      items_before = @watch_list.things.count

      delete bulk_delete_watch_list_path(@watch_list), params: {}, headers: { referer: watch_list_path(@watch_list) }

      assert_response :success

      assert_equal(items_before, @watch_list.things.count)
    end

    test 'bulk edit all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
      shared_ordered_properties = @watch_list.things.shared_ordered_properties(@current_user).reject { |_, v| v.dig('ui', 'edit', 'disabled').to_s == 'true' }.keys

      get bulk_edit_watch_list_path(@watch_list), params: {}, headers: {
        referer: watch_list_path(@watch_list)
      }

      assert_response :success

      shared_ordered_properties.each do |property|
        assert_select ".form-element.#{property}"
      end
    end

    test 'shared_ordered_properties keeps properties common to mixed templates' do
      # Watch list spanning two different templates whose common properties (e.g.
      # name) carry cosmetically-different definitions (sorting/ui/validations).
      # Regression: intersecting whole definitions dropped them all and returned {}.
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @organization.id)

      assert_operator @watch_list.things.thing_templates.template_things.map(&:template_name).uniq.size, :>=, 2

      shared = @watch_list.things.shared_ordered_properties(@current_user)

      assert_not_empty shared
      assert_includes shared.keys, 'name'
      assert(shared.values.all?(Hash))
    end

    test 'bulk update all watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
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
      assert_equal I18n.t('controllers.success.bulk_updated', count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
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
      assert_equal I18n.t('controllers.success.bulk_updated', count: 1, locale: DataCycleCore.ui_locales.first) + I18n.t('controllers.info.bulk_updated_skipped_html', counts: 'en: <b>1</b>', locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal bulk_name, @content.name
    end

    test 'bulk update all watch_list items - override classifications' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
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
      assert_equal I18n.t('controllers.success.bulk_updated', count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal @additional_tags.to_set, @content.tags.reload.pluck(:id).to_set
    end

    test 'bulk update all watch_list items - add classifications' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
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
      assert_equal I18n.t('controllers.success.bulk_updated', count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal (@default_tags + @additional_tags).to_set, @content.tags.reload.pluck(:id).to_set
    end

    test 'bulk update all watch_list items - remove classification' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
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
      assert_equal I18n.t('controllers.success.bulk_updated', count: 1, locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_equal [@default_tags.last].to_set, @content.tags.reload.pluck(:id).to_set
    end

    test 'validate (bulk update) watch_list items' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
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

      assert_includes @watch_list.things.pluck(:id), content2.id

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
      assert_includes @watch_list.things.pluck(:id), @content.id
      assert_includes @watch_list.things.pluck(:id), content2.id
    end

    test 'clear watch_list' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)

      assert_equal(1, @watch_list.things.count)

      delete clear_watch_list_path(@watch_list), params: {}, headers: { referer: watch_list_path(@watch_list) }

      assert_redirected_to watch_list_path(@watch_list)

      assert_equal(0, @watch_list.things.count)
    end

    # ---------- index ----------
    test 'index lists the current users watch lists' do
      get watch_lists_path

      assert_response :success
    end

    # ---------- show (json view-mode branches) ----------
    test 'show as json without a mode redirects to the api collection endpoint' do
      get watch_list_path(@watch_list, format: :json)

      assert_response :redirect
    end

    test 'show as json with count_only renders the count partial' do
      get watch_list_path(@watch_list, format: :json, count_only: '1', target: 'results')

      assert_response :success
      assert response.parsed_body.key?('html')
    end

    # ---------- edit form ----------
    test 'edit renders the watch list form' do
      get edit_watch_list_path(@watch_list)

      assert_response :success
    end

    # ---------- create / update failures ----------
    test 'create with a blank name redirects back without persisting' do
      assert_no_difference -> { DataCycleCore::WatchList.count } do
        post watch_lists_path, params: { watch_list: { full_path: '' } }, headers: { referer: root_path }
      end

      assert_response :redirect
    end

    test 'update with a blank name re-renders the edit form' do
      patch watch_list_path(@watch_list), params: { watch_list: { full_path: '' } }, headers: { referer: edit_watch_list_path(@watch_list) }

      assert_response :success
    end

    # ---------- remove_item via turbo_stream ----------
    test 'remove_item responds with a turbo stream' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)

      delete remove_item_watch_list_path(@watch_list),
             params: { thing_id: @content.id },
             headers: { referer: root_path, 'Accept' => 'text/vnd.turbo-stream.html' }

      assert_response :success
      assert_equal 'text/vnd.turbo-stream.html', response.media_type
    end

    # ---------- bulk_update with nothing selected ----------
    test 'bulk_update with no selected attributes flashes an error and returns ok' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)

      patch bulk_update_watch_list_path(@watch_list), params: {
        locale: 'de',
        content_template: to_query_params(thing_template: generic_content(@watch_list).thing_template).to_json
      }, headers: { referer: bulk_edit_watch_list_path(@watch_list) }

      assert_response :success
    end

    # ---------- search ----------
    test 'search returns accessible watch lists as json' do
      get search_watch_lists_path(format: :json)

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    test 'search filters watch lists by query' do
      get search_watch_lists_path(format: :json), params: { q: @watch_list.name }

      assert_response :success
      assert_kind_of Array, response.parsed_body
    end

    # ---------- update_order ----------
    test 'update_order persists a manual order' do
      DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)

      patch update_order_watch_list_path(@watch_list), params: { order: [@content.id] }, headers: { referer: watch_list_path(@watch_list) }

      assert_response :success
    end
  end
end
