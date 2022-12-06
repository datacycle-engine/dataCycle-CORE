# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentExternalConnectionsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      @external_system = DataCycleCore::ExternalSystem.first
      @current_user = DataCycleCore::User.create(DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'user').with_indifferent_access.merge({
        email: "tester_#{Time.now.getutc.to_i}@datacycle.at",
        confirmed_at: Time.zone.now - 1.day,
        role_id: DataCycleCore::Role.find_by(rank: 99)&.id
      }))
    end

    setup do
      sign_in(@current_user)
    end

    test 'create new external_connection for thing' do
      post create_external_connection_thing_path(@content), params: {
        external_system_sync: {
          external_system_id: @external_system.id,
          external_key: 'test-1'
        }
      }, headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      assert_response :success
      assert_equal I18n.t('external_connections.new_form.created', locale: @current_user.ui_locale), flash[:success]
    end

    test 'create new external_connection where it already exists' do
      @content.external_system_syncs.create({
        external_system_id: @external_system.id,
        external_key: 'test-1',
        sync_type: 'duplicate'
      })

      post create_external_connection_thing_path(@content), params: {
        external_system_sync: {
          external_system_id: @external_system.id,
          external_key: 'test-1'
        }
      }, headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      assert_response :success
      assert_equal I18n.t('external_connections.new_form.duplicate_error', locale: @current_user.ui_locale), flash[:error]
    end

    test 'create new external_connection with missing external_source_id' do
      post create_external_connection_thing_path(@content), params: {
        external_system_sync: {
          external_key: 'test-1'
        }
      }, headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      assert_response :success
      assert_equal ["#{DataCycleCore::ExternalSystemSync.human_attribute_name(:external_system_id, locale: @current_user.ui_locale)} #{I18n.t('activerecord.errors.models.data_cycle_core/external_system_sync.attributes.external_system_id.blank', locale: @current_user.ui_locale)}"], flash[:error]
    end

    test 'remove external_system_sync' do
      sync = @content.external_system_syncs.create({
        external_system_id: @external_system.id,
        external_key: 'test-1',
        sync_type: 'duplicate'
      })

      delete remove_external_connection_thing_path(@content), params: {
        external_system_sync_id: sync.id
      }, headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      assert_response :success
      assert_equal I18n.t('external_connections.remove_external_system_sync.success', locale: @current_user.ui_locale), flash[:success]
    end

    test 'remove external_source with nil value' do
      @content.update_columns(external_source_id: @external_system.id, external_key: 'test-1')

      delete remove_external_connection_thing_path(@content), params: {
        external_system_sync_id: nil
      }, headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      assert_response :success
      assert_equal I18n.t('external_connections.remove_external_system_sync.success', locale: @current_user.ui_locale), flash[:success]
    end

    test 'remove external_source with missing param' do
      @content.update_columns(external_source_id: @external_system.id, external_key: 'test-1')

      delete remove_external_connection_thing_path(@content), headers: {
        referer: polymorphic_url(@content)
      }
      follow_redirect!

      assert_response :success
      assert_equal I18n.t('external_connections.remove_external_system_sync.success', locale: @current_user.ui_locale), flash[:success]
    end
  end
end
