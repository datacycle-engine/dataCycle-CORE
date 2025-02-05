# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class ContentLockTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      include ActionView::Helpers::DateHelper

      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
        @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')
        DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, thing_id: @content.id)
        @current_user = User.find_by(email: 'tester@datacycle.at')
      end

      setup do
        sign_in(@current_user)
      end

      # test 'lock content in edit view' do
      #   get edit_thing_path(@content), params: {}, headers: {
      #     referer: thing_path(@content)
      #   }

      #   assert_response :success
      #   assert @content.lock.present?

      #   travel 1.minute
      #   freeze_time

      #   logout
      #   sign_in(User.find_by(email: 'admin@datacycle.at'))

      #   get edit_thing_path(@content), params: {}, headers: {
      #     referer: thing_path(@content)
      #   }

      #   assert_redirected_to thing_path(@content)
      #   assert_equal I18n.t(:content_locked_html, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_locales.first), flash[:alert]
      # end

      test 'lock content in bulk edit view' do
        get bulk_edit_watch_list_path(@watch_list), params: {}, headers: {
          referer: watch_list_path(@watch_list)
        }

        assert_response :success
        assert(@watch_list.things.all? { |c| c.lock.present? })

        logout
        sign_in(User.find_by(email: 'admin@datacycle.at'))

        get edit_thing_path(@content), params: {}, headers: {
          referer: thing_path(@content)
        }

        assert_redirected_to thing_path(@content)
        assert_equal I18n.t(:content_locked_html, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_locales.first), flash[:alert]
      end

      # test 'check locks for content' do
      #   @content.create_lock(user: @current_user)

      #   get check_lock_thing_path(@content), xhr: true, as: :json, params: {}, headers: {
      #     referer: thing_path(@content)
      #   }

      #   assert_response :success
      #   assert_equal response.content_type, 'application/json; charset=utf-8'
      #   json_data = JSON.parse response.body
      #   assert_equal @content.lock.id, json_data.dig('locks')&.keys&.first
      # end

      # test 'check locks for watch_list' do
      #   @watch_list.things.each { |t| t.create_lock(user: @current_user) }

      #   get check_lock_watch_list_path(@watch_list), xhr: true, as: :json, params: {}, headers: {
      #     referer: watch_list_path(@watch_list)
      #   }

      #   assert_response :success
      #   assert_equal response.content_type, 'application/json; charset=utf-8'
      #   json_data = JSON.parse response.body
      #   assert_equal @watch_list.things.first.lock.id, json_data.dig('locks')&.keys&.first
      # end

      # test 'extend content lock' do
      #   @content.create_lock(user: @current_user)
      #   updated_at = @content.lock.updated_at
      #   lock_token = DataCycleCore::JsonWebToken.encode(payload: { user_id: @current_user.id, lock_ids: Array(@content.lock&.id) }, exp: (Time.zone.now + DataCycleCore::Feature::ContentLock.lock_length.to_i)).token

      #   travel 1.minute

      #   patch content_locks_path, xhr: true, as: :json, params: {
      #     token: lock_token
      #   }, headers: {
      #     referer: edit_thing_path(@content)
      #   }

      #   assert_response :success
      #   assert_not_equal updated_at.to_i, @content.lock.reload.updated_at.to_i
      # end

      # test 'extend content lock (wrong user)' do
      #   @content.create_lock(user: @current_user)
      #   updated_at = @content.lock.updated_at

      #   travel 1.minute

      #   logout
      #   new_user = User.find_by(email: 'admin@datacycle.at')
      #   sign_in(new_user)

      #   lock_token = DataCycleCore::JsonWebToken.encode(payload: { user_id: new_user.id, lock_ids: Array(@content.lock&.id) }, exp: (Time.zone.now + DataCycleCore::Feature::ContentLock.lock_length.to_i)).token

      #   patch content_locks_path, xhr: true, as: :json, params: {
      #     token: lock_token
      #   }, headers: {
      #     referer: edit_thing_path(@content)
      #   }

      #   assert_response :success
      #   assert_equal updated_at.to_i, @content.lock.reload.updated_at.to_i
      # end

      # test 'remove content lock' do
      #   @content.create_lock(user: @current_user)

      #   lock_token = DataCycleCore::JsonWebToken.encode(payload: { user_id: @current_user.id, lock_ids: Array(@content.lock&.id) }, exp: (Time.zone.now + DataCycleCore::Feature::ContentLock.lock_length.to_i)).token

      #   post content_locks_path, xhr: true, as: :json, params: {
      #     token: lock_token
      #   }, headers: {
      #     referer: edit_thing_path(@content)
      #   }

      #   assert_response :success
      #   assert_nil @content.reload.lock
      # end

      # test 'remove content lock (wrong user)' do
      #   @content.create_lock(user: @current_user)

      #   logout
      #   new_user = User.find_by(email: 'admin@datacycle.at')
      #   sign_in(new_user)

      #   lock_token = DataCycleCore::JsonWebToken.encode(payload: { user_id: new_user.id, lock_ids: Array(@content.lock&.id) }, exp: (Time.zone.now + DataCycleCore::Feature::ContentLock.lock_length.to_i)).token

      #   post content_locks_path, xhr: true, as: :json, params: {
      #     token: lock_token
      #   }, headers: {
      #     referer: edit_thing_path(@content)
      #   }

      #   assert_response :success
      #   assert @content.reload.lock.present?
      # end

      # test 'save content while locked' do
      #   @content.create_lock(user: @current_user)

      #   patch thing_path(@content), params: {
      #     thing: {
      #       datahash: @content.get_data_hash
      #     },
      #     save_and_close: true
      #   }, headers: {
      #     referer: edit_thing_path(@content)
      #   }

      #   assert_redirected_to thing_path(@content, locale: I18n.locale)
      #   assert_nil @content.reload.lock
      # end

      # test 'remove lock for specific content' do
      #   @content.create_lock(user: @current_user)

      #   delete remove_locks_thing_path(@content), params: {
      #     id: @content.id
      #   }, headers: {
      #     referer: thing_path(@content)
      #   }

      #   assert_redirected_to thing_path(@content)
      #   assert_nil @content.reload.lock
      # end

      # test 'save content while locked (wrong user)' do
      #   @content.create_lock(user: @current_user)

      #   logout
      #   sign_in(User.find_by(email: 'admin@datacycle.at'))

      #   patch thing_path(@content), params: {
      #     thing: {
      #       datahash: @content.get_data_hash
      #     }
      #   }, headers: {
      #     referer: edit_thing_path(@content)
      #   }

      #   assert_redirected_to edit_thing_path(@content)
      #   assert @content.reload.lock.present?
      #   assert_equal I18n.t(:content_locked_html, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_locales.first), flash[:alert]
      # end

      # test 'bulk save content while locked' do
      #   @watch_list.things.each { |t| t.create_lock(user: @current_user) }

      #   patch bulk_update_watch_list_path(@watch_list), params: {
      #     thing: {
      #       datahash: {
      #         name: 'test'
      #       }
      #     },
      #     bulk_update: {
      #       name: '1'
      #     }
      #   }, headers: {
      #     referer: bulk_edit_watch_list_path(@watch_list)
      #   }

      #   assert_response :success
      #   assert(@watch_list.things.all? { |t| t.reload.lock.nil? })
      # end

      # test 'bulk save content while locked (wrong user)' do
      #   @watch_list.things.each { |t| t.create_lock(user: @current_user) }

      #   logout
      #   sign_in(User.find_by(email: 'admin@datacycle.at'))

      #   patch bulk_update_watch_list_path(@watch_list), params: {
      #     thing: {
      #       datahash: {
      #         name: 'test'
      #       }
      #     },
      #     bulk_update: {
      #       name: '1'
      #     }
      #   }, headers: {
      #     referer: bulk_edit_watch_list_path(@watch_list)
      #   }

      #   assert_redirected_to bulk_edit_watch_list_path(@watch_list)
      #   assert(@watch_list.things.all? { |t| t.reload.lock.present? })
      #   assert_equal I18n.t(:content_locked_html, scope: [:common], user: @content.lock.user&.full_name, data: distance_of_time_in_words(@content.lock.locked_for), locale: DataCycleCore.ui_locales.first), flash[:alert]
      # end
    end
  end
end
