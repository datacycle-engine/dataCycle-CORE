# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class NewContentDialogTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'new content select' do
      post contents_new_path, xhr: true, params: {
        sope: 'backend'
      }, headers: {
        referer: root_path
      }
      assert response.body.include?('Container')

      article_template = DataCycleCore::Thing.find_by(template_name: 'Artikel', template: true)
      post contents_new_path, xhr: true, params: {
        sope: 'backend',
        new_template: "source_id=>#{article_template.id},source_table=>things"
      }, headers: {
        referer: root_path
      }
      assert response.body.include?('thing[datahash][name]')
      assert response.body.include?(I18n.t('submit', locale: DataCycleCore.ui_language))
    end

    test 'remote render' do
      post remote_render_path, xhr: true, params: {
        content_for: [
          'new_content_form_title',
          'form_crumbs'
        ],
        partial: 'data_cycle_core/contents/new/new_stage',
        target: 'default_new_form',
        options: {
          scope: 'backend'
        }
      }, headers: {
        referer: root_path
      }
      assert response.body.include?('Container')

      article_template = DataCycleCore::Thing.find_by(template_name: 'Artikel', template: true)
      post remote_render_path, xhr: true, params: {
        content_for: [
          'new_content_form_title',
          'form_crumbs'
        ],
        partial: 'data_cycle_core/contents/new/new_stage',
        target: 'thing_datahash_content_location_new_form',
        options: {
          scope: 'backend',
          content: {
            class: @content.class.name,
            id: @content.id
          },
          key: 'thing_datahash_content_location',
          locale: 'de',
          object_browser: true
        },
        render_function: 'render_new_form',
        render_params: {
          new_template: {
            class: article_template.class.name,
            id: article_template.id
          }
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }
      assert response.body.include?('thing[datahash][name]')
      assert response.body.include?(I18n.t('submit', locale: DataCycleCore.ui_language))
    end
  end
end
