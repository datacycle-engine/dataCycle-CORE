# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FlashFromParamsTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @route = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'redirect to request page without flash params' do
      flash_message = 'Test Flash Message'
      get thing_path(@content), params: {
        flash: {
          success: flash_message
        }
      }, headers: {
        referer: thing_url(@content)
      }

      assert_redirected_to thing_path(@content)
      assert_equal flash_message, flash[:success]
    end
  end
end
