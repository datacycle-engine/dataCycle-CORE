# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentsControllerActionsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'ContentsControllerArtikel' })
      @source = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'ContentsControllerSource' })
      @lock_content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'ContentsControllerLockArtikel' })
      @external_system = DataCycleCore::ExternalSystem.first
      @external_content = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: {
          name: 'ContentsControllerExternalArtikel',
          external_key: 'contents-controller-test-key',
          external_source_id: @external_system.id
        }
      )
    end

    setup do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      sign_in(@current_user)
    end

    test 'bulk_create creates contents and a stored filter' do
      assert_difference -> { DataCycleCore::StoredFilter.where(user_id: @current_user.id).count } do
        post bulk_create_things_path, params: {
          template: 'Artikel',
          overlay_id: 'bulk-create-overlay',
          thing: {
            '0' => { datahash: { name: 'BulkCreateArtikel 1' }, locale: 'de', uploader_field_id: 'field-1' },
            '1' => { datahash: { name: 'BulkCreateArtikel 2' }, locale: 'de', uploader_field_id: 'field-2' }
          }
        }
      end

      assert_response :ok
      assert_predicate DataCycleCore::Thing.where_translated_value(name: 'BulkCreateArtikel 1'), :exists?
      assert_predicate DataCycleCore::Thing.where_translated_value(name: 'BulkCreateArtikel 2'), :exists?
    end

    test 'bulk_create without thing params returns no content' do
      assert_no_difference -> { DataCycleCore::Thing.count } do
        post bulk_create_things_path, params: { template: 'Artikel' }
      end

      assert_response :no_content
    end

    test 'edit_by_external_key redirects to edit path of matching content' do
      get "/things/external/#{@external_system.id}/#{@external_content.external_key}/edit"

      assert_redirected_to edit_thing_path(@external_content)
    end

    test 'edit_by_external_key responds with not_found for unknown external key' do
      get "/things/external/#{@external_system.id}/missing-external-key/edit"

      assert_response :not_found
    end

    test 'split_view renders edit view with split source' do
      get split_view_thing_path(@content, source_id: @source.id, source_locale: 'de')

      assert_response :success
      assert_includes response.body, @source.id
    end

    test 'compare renders diff view for two contents' do
      get compare_things_path, params: { id: @content.id, source_id: @source.id }

      assert_response :success
      assert_includes response.body, @content.id
    end

    test 'compare without source redirects back with alert' do
      get compare_things_path, params: { id: @content.id }, headers: { referer: thing_path(@content) }

      assert_redirected_to thing_path(@content)
      assert_equal I18n.t('controllers.error.no_source', locale: DataCycleCore.ui_locales.first), flash[:alert]
    end

    test 'remove_locks destroys existing content lock' do
      @lock_content.create_lock(user: User.find_by(email: 'tester@datacycle.at'))

      assert_predicate @lock_content.reload.lock, :present?

      delete remove_locks_thing_path(@lock_content), headers: { referer: thing_path(@lock_content) }

      assert_redirected_to thing_path(@lock_content)
      assert_equal I18n.t('controllers.success.removed_lock', locale: DataCycleCore.ui_locales.first), flash[:success]
      assert_nil @lock_content.reload.lock
    end

    test 'clear_cache invalidates content cache and redirects back' do
      cache_valid_since = @content.cache_valid_since

      delete clear_cache_thing_path(@content), headers: { referer: thing_path(@content) }

      assert_redirected_to thing_path(@content)
      assert_predicate @content.reload.cache_valid_since, :present?
      assert_not_equal cache_valid_since, @content.reload.cache_valid_since
    end

    test 'destroy_auto_translate destroys content with only manual translations' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Übersetzung', data_hash: { name: 'AutoTranslateThing' })
      translation = content.translations.first
      translation.update_columns(content: (translation.content || {}).merge('translation_type' => 'manual'))

      delete destroy_auto_translate_thing_path(content), headers: { referer: thing_path(content) }

      assert_response :redirect
      assert_not DataCycleCore::Thing.exists?(content.id)
    end

    test 'trigger_webhooks without permission redirects with alert' do
      post trigger_webhooks_thing_path(@content, webhook_action: 'update'), headers: { referer: thing_path(@content) }

      assert_redirected_to root_path
      assert_predicate flash[:alert], :present?
    end
  end
end
