# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # #47879: the eligible concept schemes of an image mostly resolve to the shared
  # universal_classifications property, which has no editor of its own. The pixie renders one editor
  # per scheme instead -- and has to resubmit the classifications of the schemes it does not render,
  # because saving replaces the whole relation.
  class AnnotationPixieFormTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    TEMPLATE_NAME = 'Bild'
    UNIVERSAL_KEY = 'universal_classifications'

    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
      @pixie = DataCycleCore::Feature::AnnotationPixie
    end

    setup do
      sign_in(@current_user)
      @content = DataCycleCore::TestPreparations.create_content(template_name: TEMPLATE_NAME, data_hash: { name: 'AnnotationPixieForm' })
      @properties = @pixie.eligible_properties(@content, @current_user)
    end

    # the schemes the pixie actually renders an editor for
    def rendered_properties
      @pixie.editor_configuration(@content, @current_user)[:editors]
    end

    # a concept the pixie renders an editor for
    def eligible_concept
      DataCycleCore::Concept.where(concept_scheme_id: rendered_properties.pluck('concept_scheme_id'), assignable: true).first
    end

    # a concept from a scheme the pixie renders no editor for, so it can only survive a save through
    # the retained hidden fields
    def foreign_concept
      visible_ids = DataCycleCore::ConceptScheme.visible('content_classifier').pluck(:id)
      DataCycleCore::Concept.where(assignable: true).where.not(concept_scheme_id: visible_ids).first
    end

    test 'the feature is available for an image and offers eligible trees' do
      assert @pixie.allowed?(@content)
      assert_predicate @properties, :present?
      assert_predicate @pixie.undedicated_properties(@content, @current_user), :present?, 'expected at least one tree without a dedicated attribute'
    end

    test 'the edit form renders one editor per tree without a dedicated attribute' do
      undedicated = rendered_properties

      get edit_thing_path(@content)

      assert_response :success
      assert_select 'div.annotation-pixie', 1
      # the editors the pixie adds are the only ones naming a concept scheme on the editor itself
      assert_select 'div.form-element[data-concept-scheme-id][data-key=?]', "thing[datahash][#{UNIVERSAL_KEY}]", undedicated.size
      undedicated.each do |property|
        # each editor is titled with its concept scheme, so the buttons are distinguishable
        assert_select 'label.attribute-edit-label', text: /#{Regexp.escape(property['concept_scheme_name'])}/
        assert_select 'div.form-element[data-concept-scheme-id=?] select', property['concept_scheme_id'], true
        # one generate button per rendered tree, each carrying exactly its own tree
        assert_select 'label.attribute-edit-label button.annotation-pixie-classify[data-concept-scheme-id=?]', property['concept_scheme_id'], 1
      end

      # every button carries the image itself -- one per eligible tree, dedicated or not. Reading it
      # from div.annotation-pixie instead left the buttons inert on a template whose eligible trees
      # all have a dedicated attribute: that div is rendered only for a tree without one, and
      # AnnotationPixie is auto-inited on the buttons.
      buttons = css_select('button.annotation-pixie-classify')

      # not a count of its own: which eligible trees render an editable attribute is instance data,
      # and the dedicated ones add their buttons on top of the undedicated editors' above
      assert_operator buttons.size, :>=, undedicated.size
      assert_equal [@content.id], buttons.pluck('data-thing-id').uniq
      assert_equal [@content.template_name], buttons.pluck('data-template-name').uniq

      # Several of these editors share one attribute name, so the upload mask's copy-to-all button
      # would carry the neighbours along -- they opt out through this attribute rather than through
      # NewContentDialog recognising a concept scheme (see #addCopyAttributeButtons).
      assert_select 'div.form-element[data-no-copy-to-all][data-key=?]', "thing[datahash][#{UNIVERSAL_KEY}]", undedicated.size
    end

    # The pixie's editors are editors of universal_classifications, so they belong where that
    # attribute sorts. Appending them to the form instead would move a scheme out of its position
    # the moment a template stops giving it an attribute of its own -- and the pixie is meant to be
    # invisible in the layout, the generate button being the only thing it adds.
    test 'the editors sit where the attribute they write sorts, not at the end of the form' do
      universal_sorting = @content.schema.dig('properties', UNIVERSAL_KEY, 'sorting').to_i
      later_keys = @content.schema['properties'].select { |_, prop| prop['sorting'].to_i > universal_sorting }.keys

      get edit_thing_path(@content)

      assert_response :success
      rendered = css_select('div.form-element[data-key]').map { |element| element['data-key'].to_s.attribute_name_from_key }
      pixie_positions = rendered.each_index.select { |index| rendered[index] == UNIVERSAL_KEY }
      later_positions = rendered.each_index.select { |index| later_keys.include?(rendered[index]) }

      assert_predicate pixie_positions, :present?, 'expected the pixie to render editors'
      assert_predicate later_positions, :present?, 'expected an editable attribute sorting after universal_classifications'
      assert_operator pixie_positions.max, :<, later_positions.max
    end

    test 'a tree with a dedicated attribute keeps its own editor and only gains the button' do
      dedicated = @properties.select { |property| @pixie.dedicated_property?(@content, property) }

      skip 'no eligible tree with a dedicated attribute in this instance' if dedicated.blank?

      get edit_thing_path(@content)

      assert_response :success
      dedicated.each do |property|
        # exactly one button for that tree: its own editor renders it, the pixie renders no second
        # editor for a tree the template already has an attribute for
        assert_select 'button.annotation-pixie-classify[data-concept-scheme-id=?]', property['concept_scheme_id'], 1
        assert_select 'select[data-tree-label=?]', property['concept_scheme_name'], 1
        # a dedicated tree's button is rendered by that attribute's own editor, so it is the one
        # that would find no .annotation-pixie to read the image off on a template with only these
        assert_select 'button.annotation-pixie-classify[data-concept-scheme-id=?][data-thing-id=?]', property['concept_scheme_id'], @content.id, 1
      end
    end

    test 'the edit form resubmits classifications of trees it renders no editor for' do
      foreign = foreign_concept

      assert_not_nil foreign, 'expected a concept from a tree that is not eligible'

      @content.set_data_hash(data_hash: { UNIVERSAL_KEY => [foreign.id] }, current_user: @current_user)

      get edit_thing_path(@content)

      assert_response :success
      assert_select 'div.annotation-pixie input[type=hidden][name=?][value=?]', "thing[datahash][#{UNIVERSAL_KEY}][]", foreign.id, 1
    end

    test 'saving what the form renders keeps both the edited and the untouched classifications' do
      foreign = foreign_concept
      eligible = eligible_concept

      assert_not_nil eligible, 'expected an assignable concept in a tree the pixie renders'

      @content.set_data_hash(data_hash: { UNIVERSAL_KEY => [foreign.id] }, current_user: @current_user)

      # what the browser submits: the blank each select contributes, the suggestion the user kept,
      # and the retained hidden value
      patch thing_path(@content), params: {
        locale: 'de',
        thing: { datahash: { UNIVERSAL_KEY => ['', eligible.id, foreign.id] } }
      }, headers: { referer: root_path }

      assert_response :redirect
      @content.reload
      stored = @content.try(UNIVERSAL_KEY).map { |classification| classification.id.to_s }

      assert_includes stored, eligible.id
      assert_includes stored, foreign.id
    end

    # The upload mask renders the pixie for a template thing, which has no asset of its own. The
    # image being uploaded reaches it only because content_uploader_data_hash memoizes the asset
    # onto that thing, and the block's data-asset-id is what both endpoints resolve the image from:
    # a request without it answers 404.
    test 'the upload mask carries the uploaded asset into the pixie block' do
      asset = upload_image('test_rgb.jpeg')
      template = DataCycleCore::ThingTemplate.find_by(template_name: TEMPLATE_NAME).template_thing

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

      assert_response :success

      body = response.parsed_body
      fragment = Nokogiri::HTML5.fragment(body.is_a?(::Hash) ? body['html'] : response.body)

      assert_not_nil fragment.at_css('.annotation-pixie'), 'expected the upload mask to render the pixie block'
      # no thing exists yet, so the buttons name the asset and the template instead
      wand = fragment.at_css('button.annotation-pixie-classify')

      assert_not_nil wand, 'expected the upload mask to render a generate button'
      assert_equal asset.id, wand['data-asset-id']
      assert_equal template.template_name, wand['data-template-name']
      assert_predicate wand['data-thing-id'].to_s, :empty?
    end

    test 'omitting the retained ids is what would delete them' do
      foreign = foreign_concept
      eligible = eligible_concept

      @content.set_data_hash(data_hash: { UNIVERSAL_KEY => [foreign.id] }, current_user: @current_user)

      patch thing_path(@content), params: {
        locale: 'de',
        thing: { datahash: { UNIVERSAL_KEY => ['', eligible.id] } }
      }, headers: { referer: root_path }

      @content.reload

      assert_not_includes @content.try(UNIVERSAL_KEY).map { |concept| concept.id.to_s }, foreign.id
    end
  end
end
