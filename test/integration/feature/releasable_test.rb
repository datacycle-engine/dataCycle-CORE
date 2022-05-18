# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class ReleasableTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
        @data_link = DataCycleCore::DataLink.find_or_create_by({
          item_id: @content.id,
          item_type: @content.class.name,
          creator_id: User.find_by(email: 'tester@datacycle.at')&.id,
          receiver_id: User.find_by(email: 'guest@datacycle.at')&.id,
          permissions: 'write'
        })
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      test 'change release status when creating external link' do
        user = DataCycleCore::TestPreparations.load_dummy_data_hash('users', 'data_link_user')

        post data_links_path, params: {
          data_link: {
            receiver: user,
            permissions: 'write',
            item_id: @content.id,
            item_type: @content.class.name
          }
        }, headers: {
          referer: thing_path(@content)
        }

        assert_redirected_to thing_path(@content)
        follow_redirect!
        assert_equal DataCycleCore::Feature::Releasable.get_stage('partner'), @content.reload.try(DataCycleCore::Feature::Releasable.allowed_attribute_keys(@content)&.first)&.reload&.first&.name
      end

      test 'change release status after finished editing content' do
        get data_link_path(@data_link)
        assert_redirected_to edit_thing_path(@content)
        follow_redirect!

        patch thing_path(@content), params: {
          thing: {
            datahash: @content.get_data_hash
          },
          finalize: true
        }, headers: {
          referer: edit_thing_path(@content)
        }

        assert_redirected_to thing_path(@content, locale: I18n.locale)
        assert_equal I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_locales.first), flash[:success]
        assert_equal DataCycleCore::Feature::Releasable.get_stage('review'), @content.reload.try(DataCycleCore::Feature::Releasable.allowed_attribute_keys(@content)&.first)&.reload&.first&.name
      end
    end
  end
end
