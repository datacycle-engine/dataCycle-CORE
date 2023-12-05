# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ReloadRequiredTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'reload_required without changes' do
      current_date = DateTime.current

      get reload_required_path, xhr: true, as: :json, params: {
        id: @content.id,
        datestring: current_date
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response 204
    end

    test 'reload_required after logout' do
      current_date = DateTime.current
      logout

      get reload_required_path, xhr: true, as: :json, params: {
        id: @content.id,
        datestring: current_date
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert json_data['error'].present?
    end

    test 'reload_required after external changes to content' do
      current_date = 1.minute.ago
      @content.set_data_hash(data_hash: { name: 'TestArtikel1' }, partial_update: true)

      get reload_required_path, xhr: true, as: :json, params: {
        id: @content.id,
        datestring: current_date
      }, headers: {
        referer: edit_thing_path(@content)
      }

      assert_response :success
      assert_equal response.content_type, 'application/json; charset=utf-8'
      json_data = response.parsed_body
      assert json_data['error'].present?
    end
  end
end
