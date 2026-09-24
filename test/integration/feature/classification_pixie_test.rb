# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # #47879 renamed the content_classifier frontend into the classificationPixie. The backend feature,
  # its route and its controller action keep their name, so this pins the parts that did change: the
  # modal's markup hooks and its own feature gate.
  class ClassificationPixieTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    TEMPLATE_NAME = 'Artikel'

    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      @content = DataCycleCore::TestPreparations.create_content(template_name: TEMPLATE_NAME, data_hash: { name: 'ClassificationPixieArtikel' })
    end

    setup do
      sign_in(@current_user)
    end

    test 'the feature is gated on the content classifier backend feature' do
      pixie = DataCycleCore::Feature['ClassificationPixie']

      assert_not_nil pixie
      assert_predicate pixie, :enabled?
      assert pixie.allowed?(@content)
      # unlike the annotationPixie it is not restricted to images
      assert_not DataCycleCore::Feature::AnnotationPixie.allowed?(@content)
    end

    test 'the modal body renders under the pixie markup hooks' do
      get content_classifier_form_body_thing_path(@content)

      assert_response :success
      assert_select 'div.classification-pixie-form', 1
      assert_select "turbo-frame#classification_pixie_#{@content.id}_frame", 1
      assert_select 'button.classification-pixie-tree-item'
    end

    test 'the modal body is refused while the pixie is not allowed' do
      DataCycleCore::Feature::ClassificationPixie.stub(:allowed?, ->(*) { false }) do
        get content_classifier_form_body_thing_path(@content), headers: JSON_HEADERS
      end

      # the route is drawn unconditionally, so the feature verdict has to be enforced per request
      # and not only on the button that opens the modal
      assert_response :unauthorized
    end

    test 'the detail view offers the modal for an editable content' do
      get thing_path(@content)

      assert_response :success
      assert_select 'button[data-toggle=?]', "classification_pixie_#{@content.id}", 1
      assert_select "div.reveal#classification_pixie_#{@content.id}", 1
    end
  end
end
