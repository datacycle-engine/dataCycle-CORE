# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # #47879: the focus point suggestion endpoint. The annotation service is stubbed -- what is under
  # test is the request the endpoint builds and the guards it applies, not the service.
  class AnnotationPixieSuggestionTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    TEMPLATE_NAME = 'Bild'
    NON_IMAGE_TEMPLATE_NAME = 'Artikel'

    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
    end

    setup do
      sign_in(@current_user)
    end

    def image_content(name)
      pixie_image(name, template_name: TEMPLATE_NAME)
    end

    test 'the eligibility both entry points share also resolves on an unsaved thing' do
      template = DataCycleCore::Thing.new(template_name: TEMPLATE_NAME)

      assert DataCycleCore::Feature::AnnotationPixie.allowed?(template)
      assert_predicate DataCycleCore::Feature::AnnotationPixie.eligible_properties(template, @current_user), :present?, 'expected an eligible tree on a fresh Bild (upload mask)'
    end

    test 'it answers with the annotated focus point of a content' do
      content = image_content('AnnotationPixieFocusPoint')

      calls = stub_embedding({ 'focus_point' => { 'x' => 0.25, 'y' => 0.75 } }) do
        post focus_point_suggestion_things_path, params: { thing_id: content.id }, headers: JSON_HEADERS
      end

      assert_response :success
      assert_in_delta 0.25, response.parsed_body.dig('focus_point', 'x')
      assert_in_delta 0.75, response.parsed_body.dig('focus_point', 'y')
      assert_equal content.asset.public_url, calls.sole[:image_url]
    end

    test 'it answers with no focus point when the service found none' do
      content = image_content('AnnotationPixieNoFocusPoint')

      stub_embedding({}) do
        post focus_point_suggestion_things_path, params: { thing_id: content.id }, headers: JSON_HEADERS
      end

      assert_response :success
      assert_nil response.parsed_body['focus_point']
    end

    test 'it works for an asset that has no content yet' do
      asset = upload_image('test_rgb.jpeg')

      calls = stub_embedding({ 'focus_point' => { 'x' => 0.4, 'y' => 0.6 } }) do
        post focus_point_suggestion_things_path, params: { asset_id: asset.id, template_name: TEMPLATE_NAME }, headers: JSON_HEADERS
      end

      assert_response :success
      assert_in_delta 0.4, response.parsed_body.dig('focus_point', 'x')
      assert_equal asset.public_url, calls.sole[:image_url]
    end

    test 'the image url is derived from the asset, never from the request' do
      asset = upload_image('test_rgb.jpeg')

      calls = stub_embedding({}) do
        post focus_point_suggestion_things_path, params: {
          asset_id: asset.id,
          template_name: TEMPLATE_NAME,
          image_url: 'https://attacker.example.org/expensive.jpg'
        }, headers: JSON_HEADERS
      end

      assert_response :success
      assert_equal asset.public_url, calls.sole[:image_url]
    end

    test 'a focus point the service shaped differently answers nil instead of failing' do
      content = image_content('AnnotationPixieOddFocusPoint')

      stub_embedding({ 'focus_point' => [0.25, 0.75] }) do
        post focus_point_suggestion_things_path, params: { thing_id: content.id }, headers: JSON_HEADERS
      end

      assert_response :success
      assert_nil response.parsed_body['focus_point']
    end

    # Both coordinates are fractions of the image's size, and the editor clamps only the crosshair
    # it draws, so an out of range answer would be shown on the edge and persisted past it.
    test 'a focus point outside the image is clamped to its edges' do
      content = image_content('AnnotationPixieOutOfRangeFocusPoint')

      stub_embedding({ 'focus_point' => { 'x' => 1.4, 'y' => -0.2 } }) do
        post focus_point_suggestion_things_path, params: { thing_id: content.id }, headers: JSON_HEADERS
      end

      assert_response :success
      assert_in_delta 1.0, response.parsed_body.dig('focus_point', 'x')
      assert_in_delta 0.0, response.parsed_body.dig('focus_point', 'y')
    end

    test 'it refuses a non-image template' do
      asset = upload_image('test_rgb.jpeg')

      post focus_point_suggestion_things_path, params: { asset_id: asset.id, template_name: NON_IMAGE_TEMPLATE_NAME }, headers: JSON_HEADERS

      assert_response :unauthorized
    end

    test 'it refuses an unknown template' do
      asset = upload_image('test_rgb.jpeg')

      post focus_point_suggestion_things_path, params: { asset_id: asset.id, template_name: 'NotATemplate' }, headers: JSON_HEADERS

      assert_response :not_found
    end

    test 'it refuses an unknown asset' do
      post focus_point_suggestion_things_path, params: { asset_id: SecureRandom.uuid, template_name: TEMPLATE_NAME }, headers: JSON_HEADERS

      assert_response :not_found
    end
  end
end
