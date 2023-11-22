# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class NamedVersionTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' }, version_name: 'Test Version 1')
        @current_user = User.find_by(email: 'tester@datacycle.at')
      end

      setup do
        sign_in(@current_user)
      end

      test 'remove version_name from content' do
        patch remove_version_name_path, params: {
          class_name: @content.class.name,
          id: @content.id
        }, headers: {
          referer: thing_path(@content)
        }

        assert_redirected_to thing_path(@content)
        assert_equal I18n.t('feature.named_version.version_name_removed', locale: DataCycleCore.ui_locales.first), flash[:notice]
        assert_nil @content.reload.version_name
      end

      test 'remove version_name from history entry' do
        version_name = 'Version 2'
        @content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, partial_update: true, version_name:)
        history_entry = @content.histories.first

        patch remove_version_name_path, params: {
          class_name: history_entry.class.name,
          id: history_entry.id
        }, headers: {
          referer: thing_path(@content)
        }

        assert_redirected_to thing_path(@content)
        assert_equal I18n.t('feature.named_version.version_name_removed', locale: DataCycleCore.ui_locales.first), flash[:notice]
        assert_nil history_entry.reload.version_name
        assert_equal version_name, @content.reload.version_name
      end
    end
  end
end
