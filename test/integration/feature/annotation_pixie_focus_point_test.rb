# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # #47879: focus_point_x/y are `:visible: api` and have no edit field anywhere. The pixie offers
  # its suggestion inside the focus point editor on the detail page and writes through that
  # editor's endpoint (PATCH /things/:id/update_focus_point) -- this covers what the page hands the
  # editor to render the generate button from, and the two-step flow the button performs. The
  # ordinary save paths (PATCH /things/:id, POST /things/bulk_create) are covered too, because an
  # api-only attribute silently dropped on the way in would force a write path of the pixie's own.
  class AnnotationPixieFocusPointTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    TEMPLATE_NAME = 'Bild'

    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      # the pixie writes through the focus point editor's endpoint, so those are its keys too
      @focus_point_keys = DataCycleCore::Feature::FocusPointEditor.attribute_keys
    end

    setup do
      sign_in(@current_user)
    end

    def create_image(name, with_asset: false)
      pixie_image(name, template_name: TEMPLATE_NAME, with_asset:)
    end

    test 'the detail page renders the generate button with the editor it fills' do
      content = create_image('AnnotationPixieFocusPointButton')

      get thing_path(content)

      assert_response :success
      # the editor's own target, because the pixie writes a generated point through that endpoint
      assert_select 'button.change-focus-point-ui[data-thing-id=?]', content.id, 1
      assert_select 'button.change-focus-point-ui[data-focus-point-x-key=?][data-focus-point-y-key=?]', @focus_point_keys.first, @focus_point_keys.second, 1
      # the generate button and the reset belong to an open editor and are hidden until it is open,
      # so they carry .editing-control rather than being rendered by the editor itself
      assert_select 'div.focus-feature-buttons div.editing-control--focus-point button.annotation-pixie-focus-point', 1
      assert_select 'div.focus-feature-buttons div.editing-control--focus-point button.focus-point-clear', 1
      assert_select 'p.editing-control--focus-point', text: I18n.t('feature.focus_point_editor.hint', locale: :de), count: 1
    end

    # Each hint belongs to one editor, and the gravity default is a statement about gravity: it was
    # appended to the focus point editor's hint, which shows only while that editor is open, and
    # gravity_editor.hint was deleted along with the <p> the two details partials rendered it in.
    # The gravity editor is not enabled in core's dummy, so this is where the split is pinned.
    test 'the gravity default is the gravity editor own hint, in every locale' do
      ['de', 'en'].each do |locale|
        gravity = I18n.t('feature.gravity_editor.hint', locale:)
        focus_point = I18n.t('feature.focus_point_editor.hint', locale:)

        assert_not_includes gravity, 'translation missing', "expected feature.gravity_editor.hint in #{locale}"
        assert_not_includes focus_point, gravity, "expected the gravity default out of the focus point hint in #{locale}"
      end
    end

    # The partial asks Feature['AnnotationPixie']&.allowed?(content) once and renders the wand and
    # its hint from that one answer, so a disabled feature and an image the service cannot be asked
    # about are the same case here -- #allowed? folds :enabled: into itself.
    test 'an image the annotation service cannot be asked about gets the editor without the wand' do
      content = create_image('AnnotationPixieFocusPointWithoutPixie')

      DataCycleCore::Feature::AnnotationPixie.stub(:allowed?, ->(*) { false }) do
        get thing_path(content)
      end

      assert_response :success
      # the manual editor is the focus point editor's own right and stands without the pixie
      assert_select 'button.change-focus-point-ui', 1
      assert_select 'button.focus-point-clear', 1
      assert_select 'button.annotation-pixie-focus-point', 0
      # the wand's hint names the pixie ("Der annotationPixie bestimmt den Fokuspunkt aus der
      # Bildanalyse."), so it has to go with the wand rather than stay behind as a promise the page
      # cannot keep -- it sits in the same block, and this is what says so
      ['de', 'en'].each do |locale|
        assert_select 'p', text: I18n.t('feature.annotation_pixie.focus_point_hint', locale:), count: 0
      end
      # and the focus point editor keeps its own hint, which is what tells the user to click
      assert_select 'p.editing-control--focus-point', text: I18n.t('feature.focus_point_editor.hint', locale: :de), count: 1
    end

    test 'the suggested point is stored through the focus point editor endpoint' do
      content = create_image('AnnotationPixieFocusPointGenerate', with_asset: true)

      stub_embedding({ 'focus_point' => { 'x' => 0.25, 'y' => 0.75 } }) do
        post focus_point_suggestion_things_path, params: { thing_id: content.id }, headers: JSON_HEADERS
      end

      assert_response :success
      suggestion = response.parsed_body['focus_point']

      # what the button does with the answer: the manual editor's own write, unchanged. Sent as
      # json like the button sends it -- the endpoint hands the values to set_data_hash unparsed,
      # and the number validator rejects the "0.25" a form-encoded request would deliver
      patch update_focus_point_path(content), params: {
        focus_point: {
          @focus_point_keys.first => suggestion['x'],
          @focus_point_keys.second => suggestion['y']
        }
      }, as: :json

      assert_response :success
      content.reload

      assert_in_delta 0.25, content.try(@focus_point_keys.first)
      assert_in_delta 0.75, content.try(@focus_point_keys.second)
    end

    test 'focus point keys are api-only floats, so the regular save path is what has to be proven' do
      template = DataCycleCore::Thing.new(template_name: TEMPLATE_NAME)

      assert_equal ['focus_point_x', 'focus_point_y'], @focus_point_keys
      @focus_point_keys.each do |key|
        definition = template.properties_for(key)

        # `:visible: api` is normalized into per-scope ui flags, so this is what "no edit field of
        # its own, written by the pixie through hidden fields" looks like on the template.
        assert definition.dig('ui', 'edit', 'disabled'), "#{key} is expected to have no edit field"
        # without the explicit float format, DataHashService parses submitted numbers with to_i and
        # a focus point of 0.25 would silently persist as 0
        assert_equal 'float', definition.dig('validations', 'format'), "#{key} is expected to be a float"
      end
    end

    test 'the detail edit save persists a focus point written into hidden fields' do
      content = create_image('AnnotationPixieFocusPointUpdate')

      patch thing_path(content), params: {
        locale: 'de',
        thing: {
          datahash: {
            @focus_point_keys.first => '0.25',
            @focus_point_keys.second => '0.75'
          }
        }
      }, headers: { referer: root_path }

      assert_response :redirect
      content.reload

      assert_in_delta 0.25, content.try(@focus_point_keys.first)
      assert_in_delta 0.75, content.try(@focus_point_keys.second)
    end

    test 'bulk_create persists a focus point written into hidden fields' do
      post bulk_create_things_path, params: {
        template: TEMPLATE_NAME,
        overlay_id: 'annotation-pixie-overlay',
        thing: {
          '0' => {
            datahash: {
              name: 'AnnotationPixieFocusPointUpload',
              @focus_point_keys.first => '0.1',
              @focus_point_keys.second => '0.9'
            },
            locale: 'de',
            uploader_field_id: 'annotation-pixie-field'
          }
        }
      }

      assert_response :ok
      content = DataCycleCore::Thing.where_translated_value(name: 'AnnotationPixieFocusPointUpload').first

      assert_not_nil content
      assert_in_delta 0.1, content.try(@focus_point_keys.first)
      assert_in_delta 0.9, content.try(@focus_point_keys.second)
    end
  end
end
