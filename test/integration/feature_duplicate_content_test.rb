# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FeatureDuplicateContentTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'create duplicate of content' do
      get create_duplication_thing_path(@content), params: {}, headers: {
        referer: thing_path(@content)
      }

      assert_response 302
      duplicate = DataCycleCore::Thing.find_by(name: "DUPLICATE: #{@content.name}")
      assert duplicate.present?
      assert_not_equal @content.id, duplicate.id
    end
  end
end
