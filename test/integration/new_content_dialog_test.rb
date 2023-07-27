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
      get new_thing_path, xhr: true, params: {
        sope: 'backend',
        template: 'Artikel'
      }, headers: {
        referer: root_path
      }
      assert response.body.include?('thing[datahash][name]')
    end

    test 'remote render' do
      post remote_render_path, xhr: true, params: {
        partial: 'data_cycle_core/contents/new/shared/new_form',
        target: 'default_new_form',
        options: {
          scope: 'backend'
        }
      }, headers: {
        referer: root_path
      }
      assert response.body.include?('Container')

      article_template = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
      post remote_render_path, xhr: true, params: {
        partial: 'data_cycle_core/contents/new/shared/new_form',
        target: 'thing_datahash_content_location_new_form',
        options: {
          scope: 'backend',
          content: {
            class: @content.class.name,
            id: @content.id
          },
          key: 'thing_datahash_content_location',
          locale: 'de',
          object_browser: true,
          template: {
            id: article_template&.id,
            class: article_template&.class&.name
          }
        }
      }, headers: {
        referer: edit_thing_path(@content)
      }
      assert response.body.include?('thing[datahash][name]')
    end
  end
end
