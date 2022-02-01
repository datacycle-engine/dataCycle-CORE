# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ThingHistoryTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    before(:all) do
      @routes = Engine.routes
      @current_user = User.find_by(email: 'tester@datacycle.at')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      @organization = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'TestOrganization' })
    end

    setup do
      sign_in(@current_user)
    end

    test 'restore version from history' do
      @content.set_data_hash(data_hash: {
        name: 'update name 1'
      }.deep_stringify_keys, partial_update: true)

      assert_equal 'update name 1', @content.name

      history_entry = @content.histories.first
      history_date = (history_entry.try(:history_valid)&.first || history_entry.try(:updated_at))&.in_time_zone
      history_date_string = I18n.l(history_date, locale: DataCycleCore.ui_locales.first, format: :history) if history_date.present?

      post restore_history_version_thing_path(id: @content.id, history_id: history_entry.id)
      assert_redirected_to thing_path(@content)
      assert_equal I18n.t(:restored, scope: [:history, :restore, :version], locale: DataCycleCore.ui_locales.first, date: history_date_string), flash[:success]

      assert_equal 'TestArtikel', @content.reload.name
    end

    test 'restore version from history with translated content' do
      @organization.set_data_hash_with_translations(data_hash: {
        translations: {
          de: { name: 'update de 1' },
          en: { name: 'update en 1' }
        }
      }.deep_stringify_keys, partial_update: true)

      assert_equal 'update de 1', I18n.with_locale(:de) { @organization.name }
      assert_equal 'update en 1', I18n.with_locale(:en) { @organization.name }

      history_entry = @organization.histories.last

      history_date = I18n.with_locale(:de) { (history_entry.try(:history_valid)&.first || history_entry.try(:updated_at))&.in_time_zone }
      history_date_string = I18n.l(history_date, locale: DataCycleCore.ui_locales.first, format: :history) if history_date.present?

      post restore_history_version_thing_path(id: @organization.id, history_id: history_entry.id)
      assert_redirected_to thing_path(@organization)
      assert_equal I18n.t(:restored, scope: [:history, :restore, :version], locale: DataCycleCore.ui_locales.first, date: history_date_string), flash[:success]

      assert_equal 'TestOrganization', I18n.with_locale(:de) { @organization.reload.name }
      assert_equal 'update en 1', I18n.with_locale(:en) { @organization.reload.name }
    end
  end
end
