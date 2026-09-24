# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # What a project that merges the pixies without turning them on gets (#47879, #47881).
  #
  # The three features own UI that is rendered into surfaces they do not own -- the focus point
  # editor's button column on an image's detail page, the toolbar of every text editor, the
  # classification editors of the edit form, the upload mask -- and their routes and controller
  # mixins are wired at boot, before any flag is read. So the rollout question is not whether the
  # pixies work, but whether everything they were woven into still works with all three off.
  #
  # #with_pixies_disabled flips :enabled: and :allowed: rather than stubbing #allowed?, because
  # #enabled? reads DataCycleCore.features itself.
  class PixiesDisabledTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    TEMPLATE_NAME = 'Bild'

    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      @focus_point_keys = DataCycleCore::Feature::FocusPointEditor.attribute_keys
    end

    setup do
      sign_in(@current_user)
      @content = pixie_image('PixiesDisabled', with_asset: true)
    end

    test 'all three report themselves unavailable' do
      with_pixies_disabled do
        ['AnnotationPixie', 'ImageDescriptionPixie', 'ClassificationPixie'].each do |name|
          feature = DataCycleCore::Feature[name]

          assert_not_predicate feature, :enabled?, "expected #{name} disabled"
          assert_not feature.allowed?(@content), "expected #{name} not allowed"
        end
      end
    end

    # The manual focus point editor and the gravity editor are features of their own, and their
    # button column is the one surface a pixie renders into on a *detail* page.
    test 'the image detail page keeps the manual focus point editor and loses every wand' do
      with_pixies_disabled { get thing_path(@content) }

      assert_response :success
      assert_select 'div.focus-feature-buttons', 1
      assert_select 'button.change-focus-point-ui[data-thing-id=?]', @content.id, 1
      assert_select 'button.change-focus-point-ui[data-focus-point-x-key=?][data-focus-point-y-key=?]', @focus_point_keys.first, @focus_point_keys.second, 1
      # resetting is the editor's own, so it stays
      assert_select 'button.focus-point-clear', 1
      # and the editor keeps the hint that tells the user to click into the image
      assert_select 'p.editing-control--focus-point', text: I18n.t('feature.focus_point_editor.hint', locale: :de), count: 1

      assert_select 'button.annotation-pixie-focus-point', 0
      assert_select '.pixie-generate-button', 0
      assert_select 'button.content-classifier-button', 0
      ['de', 'en'].each do |locale|
        assert_select 'p', text: I18n.t('feature.annotation_pixie.focus_point_hint', locale:), count: 0
      end
    end

    # The pixie's classification editors replace the shared universal_classifications attribute in
    # the form and take its position. With the pixie off that attribute has to be back to whatever
    # it rendered before -- nothing, since it carries no tree_label -- and every dedicated
    # classification editor has to render as it always did.
    test 'the edit form renders its classification editors without the pixie' do
      with_pixies_disabled { get edit_thing_path(@content) }

      assert_response :success
      assert_select 'div.annotation-pixie', 0
      assert_select 'div.form-element[data-concept-scheme-id]', 0
      assert_select 'button.annotation-pixie-classify', 0
      assert_select '.pixie-generate-button', 0
      # the form still renders editors, i.e. the pixie's guards did not swallow the attribute loop
      assert_select 'div.form-element', minimum: 5
    end

    # Opts a text attribute in the way datacycle-feature-embedding's template set does, so the
    # imageDescriptionPixie's wand has somewhere to render. Core's own dummy opts none in, which is
    # what would make the assertion below pass for the wrong reason.
    def with_text_property(key, source, &)
      configuration = { 'allowed' => true, 'attribute_keys' => [key] }

      DataCycleCore::Feature::ImageDescriptionPixie.stub(:configuration, lambda { |_content = nil, asked = nil|
        if asked.nil?
          configuration
        else
          configuration.merge('source' => (asked.to_s == key ? source : nil))
        end
      }, &)
    end

    # Both wands sit in a text editor's toolbar next to the aiLector's dropdown, and
    # _attribute_action_buttons renders the two from one partial -- so a project that ships the
    # template opt-in but never enables the feature is the case to pin: the opt-in stands and the
    # wand still has to stay away, while the aiLector beside it is untouched.
    test 'a text editor toolbar keeps the aiLector button and loses the pixie wand' do
      lector = DataCycleCore::Feature['AiLector']

      # with the feature on, the opt-in puts a wand in that toolbar -- otherwise the assertion
      # below would hold whatever the guards did
      with_text_property('description', 'alt_text') { get edit_thing_path(@content) }

      assert_response :success
      assert_select '.image-description-pixie-button', { minimum: 1 }, 'expected the opt-in to render a wand while the feature is on'

      with_pixies_disabled do
        with_text_property('description', 'alt_text') { get edit_thing_path(@content) }
      end

      assert_response :success
      assert_select '.image-description-pixie-button', 0
      # the editor the wand sat in is still rendered
      assert_select 'div.form-element[data-key*=?]', 'description', { minimum: 1 }, 'expected the description editor without its wand'
      # the aiLector is enabled independently and renders from the same partial
      assert_select '.ai-lector-dropdown-button', (lector&.enabled? ? { minimum: 1 } : 0)
    end

    # Every pixie route is drawn at boot -- Routes::AnnotationPixie and friends run before any flag
    # is read -- so with the feature off they have to fail closed rather than 500 on a half-wired
    # feature. CanCan::AccessDenied is what #with_image_annotation raises, and this app answers it
    # with 401 for an XHR.
    test 'the suggestion endpoints deny the request' do
      with_pixies_disabled do
        post focus_point_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS

        assert_response :unauthorized

        post description_suggestion_things_path, params: { thing_id: @content.id, attribute_key: 'description', locale: 'de' }, headers: JSON_HEADERS

        assert_response :unauthorized
      end
    end

    # The classificationPixie's modal body is a member route on things, drawn unconditionally, so
    # the guard is in the action rather than only on the button that opens the modal.
    test 'the classification pixie form body denies the request' do
      with_pixies_disabled do
        get content_classifier_form_body_thing_path(@content), headers: JSON_HEADERS
      end

      assert_response :unauthorized
    end

    # The upload mask renders the whole attribute form once per file and is where the pixies add
    # both a wand and an "apply to all files" button. It is reached the way AssetFile reaches it,
    # through remote_render with render_attributes -- a plain GET /things/new renders the template
    # picker instead.
    test 'the upload mask renders without the pixies' do
      asset = upload_image('test_rgb.jpeg')
      template = DataCycleCore::ThingTemplate.find_by(template_name: TEMPLATE_NAME).template_thing

      with_pixies_disabled do
        post remote_render_path, xhr: true, params: {
          partial: 'data_cycle_core/contents/new/shared/new_form',
          options: {
            scope: 'backend',
            content_uploader: true,
            asset: { class: asset.class.name, id: asset.id },
            options: { render_attributes: true, prefix: 'upload_1_' },
            template: { class: template.class.name, attributes: template.attributes }
          }
        }, headers: { referer: root_path }
      end

      assert_response :success

      body = response.parsed_body
      fragment = Nokogiri::HTML5.fragment(body.is_a?(::Hash) ? body['html'] : response.body)

      # the mask still renders the form it always rendered
      assert_predicate fragment.css('.form-element'), :present?, 'expected the upload mask to render its attribute editors'

      assert_nil fragment.at_css('.annotation-pixie'), 'expected no pixie block'
      assert_nil fragment.at_css('.pixie-generate-button'), 'expected no wand'
      assert_nil fragment.at_css('.pixie-to-all-files'), 'expected no apply-to-all button'
      assert_nil fragment.at_css('button.annotation-pixie-classify'), 'expected no classify button'
    end

    # The fold of #dependencies_allowed? into #allowed? is the one change of this branch that
    # reaches every feature. Disabling the pixies must not disable anything else, and nothing that
    # existed before the fold may become unavailable because a dependency is now checked.
    test 'no other feature loses its availability' do
      before_state = feature_availability

      with_pixies_disabled do
        assert_equal before_state, feature_availability.except('annotation_pixie', 'image_description_pixie', 'classification_pixie')
      end
    end

    # #allowed? of a feature declaring a target locale or a download scope takes more than a
    # content, so those answer by their arity here rather than being called wrongly.
    def feature_availability
      DataCycleCore.features.keys.to_h { |key|
        feature = DataCycleCore::Feature[key.to_s.camelize]
        available =
          if feature.nil?
            nil
          elsif feature.method(:allowed?).arity.abs > 1
            feature.enabled?
          else
            feature.allowed?(@content).present?
          end

        [key.to_s, available]
      }.except('annotation_pixie', 'image_description_pixie', 'classification_pixie')
    end
  end
end
