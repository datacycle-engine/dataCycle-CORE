# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # #47881: the text suggestion endpoint. PixieLens answers focus point and texts in one response,
  # so the imageDescriptionPixie reads the same annotation the annotationPixie already asks for --
  # which only pays off while both ask with identical arguments (Feature::Embedding caches per url +
  # languages + generate_tags), and both ask for the one locale being edited. The service is
  # stubbed; what is under test is the request the endpoint builds, the guards it applies and how it
  # maps the annotation onto the attribute being filled.
  class ImageDescriptionPixieTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
    TEMPLATE_NAME = 'Bild'
    NON_IMAGE_TEMPLATE_NAME = 'Artikel'
    ANNOTATION = {
      'alt_text' => { 'de' => 'Ein Feld voller Lavendel', 'en' => 'A field of lavender' },
      'title' => { 'de' => 'Lavendelfeld', 'en' => 'Lavender field' },
      'captions' => { 'de' => 'Lavendel im Abendlicht', 'en' => 'Lavender at dusk' },
      'focus_point' => { 'x' => 0.25, 'y' => 0.75 }
    }.freeze

    before(:all) do
      @current_user = User.find_by(email: 'admin@datacycle.at')
    end

    setup do
      sign_in(@current_user)
      @content = pixie_image('ImageDescriptionPixie', template_name: TEMPLATE_NAME)
    end

    # Opts the given attributes in the way a template would, for the duration of the block.
    def with_text_properties(properties, &)
      configuration = {
        'allowed' => true,
        'attribute_keys' => properties.keys
      }

      DataCycleCore::Feature::ImageDescriptionPixie.stub(:configuration, lambda { |_content = nil, key = nil|
        key.nil? ? configuration : configuration.merge('source' => properties[key.to_s])
      }, &)
    end

    # What the computed ALT label is configured to generate, which the endpoints must not read.
    def with_feature_languages(languages, &)
      DataCycleCore::Feature::ImageDescriptionPixie.stub(:generate_languages, ->(*) { languages }, &)
    end

    # An annotation already kept on the content's embedding row, as a backfilled image has one.
    def with_stored_annotation(data, &)
      DataCycleCore::Feature['Embedding'].stub(:stored_annotation, ->(_content) { data }, &)
    end

    test 'it answers with one suggestion per opted-in attribute, keyed by locale' do
      # the three text attributes Bild opts in (datacycle-feature-embedding's feature_image_description
      # template set): every one of them is read from the same annotation
      with_text_properties('description' => 'alt_text', 'name' => 'title', 'caption' => 'captions') do
        stub_embedding(ANNOTATION) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      texts = response.parsed_body['texts']

      # keyed by locale, but only the one being edited: the editor a wand sits in writes that
      # translation and nothing else
      assert_equal({ 'de' => 'Ein Feld voller Lavendel' }, texts['description'])
      assert_equal({ 'de' => 'Lavendelfeld' }, texts['name'])
      assert_equal({ 'de' => 'Lavendel im Abendlicht' }, texts['caption'])
    end

    test 'an attribute that did not opt in is not suggested' do
      with_text_properties('description' => 'alt_text') do
        stub_embedding(ANNOTATION) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      assert_equal ['description'], response.parsed_body['texts'].keys
    end

    test 'it asks the annotation service for the one locale being edited' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        calls = stub_embedding(ANNOTATION) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_equal 1, calls.size
      # every further language is a vision call of its own, and the editor has nowhere to put it
      assert_equal ['de'], calls.first[:languages]
      assert_equal @content.asset.public_url, calls.first[:image_url]
    end

    test 'a wand in another translation of the attribute asks for that locale' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        calls = stub_embedding(ANNOTATION) do
          post description_suggestion_things_path, params: { thing_id: @content.id, locale: 'en' }, headers: JSON_HEADERS
        end
      end

      # the form renders the other translations without reloading, so the request names the locale
      # of the editor the wand sits in rather than the one the backend is read in
      assert_equal ['en'], calls.first[:languages]
      assert_equal({ 'en' => 'A field of lavender' }, response.parsed_body.dig('texts', 'description'))
    end

    test 'a locale the system does not have falls back to the request locale' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        calls = stub_embedding(ANNOTATION) do
          post description_suggestion_things_path, params: { thing_id: @content.id, locale: 'xx' }, headers: JSON_HEADERS
        end
      end

      assert_equal ['de'], calls.first[:languages]
    end

    test 'an imported image is annotated from its own url, having no asset of its own' do
      # what Wikidata and Canto (#49225) deliver: the file stays where it is and the Bild carries
      # its url. Before this the endpoint asked the asset for a url, got nil, and answered
      # "Keine Daten angegeben für Bild" on every imported image.
      imported = DataCycleCore::TestPreparations.create_content(template_name: TEMPLATE_NAME, data_hash: { name: 'Imported' })
      imported.update_columns(metadata: (imported.metadata || {}).merge('content_url' => 'https://cdn.example.org/imported.jpg'))
      imported.reload
      calls = nil

      assert_nil imported.asset

      with_text_properties('description' => 'alt_text') do
        calls = stub_embedding(ANNOTATION) do
          post focus_point_suggestion_things_path, params: { thing_id: imported.id }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      assert_equal 1, calls.size
      # the computed label's order of parameters, so both read one annotation: the imgproxy web
      # version where the content has one, content_url behind it
      assert_equal imported.virtual_web_url, calls.first[:image_url]
    end

    test 'a focus point request asks for one language, whatever the texts pixie is configured for' do
      calls = nil

      with_feature_languages(['de', 'en']) do
        with_text_properties('description' => 'alt_text') do
          calls = stub_embedding(ANNOTATION) do
            post focus_point_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
          end
        end
      end

      assert_response :success
      assert_equal 1, calls.size
      # a focus point is the same point in every language, and one is the floor: PixieLens answers
      # an absent :languages: with its own default of [de, en], so leaving the field out would buy
      # a second language of text nobody reads
      assert_equal ['de'], calls.first[:languages]
    end

    test 'the focus point and the texts of one image are asked for identically, so they share the cache' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        calls = stub_embedding(ANNOTATION) do
          post focus_point_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_equal 2, calls.size
      assert_equal calls.first, calls.second, 'both endpoints have to hit the same Feature::Embedding cache entry'
    end

    test 'an attribute the service returned nothing for is omitted' do
      with_text_properties('description' => 'alt_text', 'caption' => 'captions') do
        stub_embedding(ANNOTATION.except('captions')) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      assert_equal ['description'], response.parsed_body['texts'].keys
    end

    test 'a bare string is offered under the locale it was asked for' do
      with_text_properties('description' => 'alt_text') do
        stub_embedding({ 'alt_text' => 'A field of lavender' }) do
          post description_suggestion_things_path, params: { thing_id: @content.id, locale: 'en' }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      # a provider answering without a language claims none, and the editor looks its suggestion up
      # by the locale it edits
      assert_equal({ 'en' => 'A field of lavender' }, response.parsed_body.dig('texts', 'description'))
    end

    test 'a stored annotation answers without asking the service' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        with_stored_annotation(ANNOTATION) do
          calls = stub_embedding(ANNOTATION) do
            post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
          end
        end
      end

      assert_response :success
      # a backfilled image has been annotated once already, and the row outlives the three day
      # cache Feature::Embedding keeps -- so the wand costs nothing and answers at once
      assert_empty calls
      assert_equal({ 'de' => 'Ein Feld voller Lavendel' }, response.parsed_body.dig('texts', 'description'))
    end

    test 'a stored annotation without the locale being edited still asks the service' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        with_stored_annotation({ 'alt_text' => { 'de' => 'Ein Feld voller Lavendel' } }) do
          calls = stub_embedding(ANNOTATION) do
            post description_suggestion_things_path, params: { thing_id: @content.id, locale: 'en' }, headers: JSON_HEADERS
          end
        end
      end

      assert_response :success
      # the label was generated in German alone, which cannot fill an English editor: asking the
      # service is the point of this click
      assert_equal ['en'], calls.first[:languages]
      assert_equal({ 'en' => 'A field of lavender' }, response.parsed_body.dig('texts', 'description'))
    end

    test 'a stored focus point answers the focus point endpoint whatever it was generated for' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        with_stored_annotation({ 'focus_point' => { 'x' => 0.25, 'y' => 0.75 } }) do
          calls = stub_embedding(ANNOTATION) do
            post focus_point_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
          end
        end
      end

      assert_response :success
      assert_empty calls
      assert_equal({ 'x' => 0.25, 'y' => 0.75 }, response.parsed_body['focus_point'])
    end

    test 'a stored annotation without a focus point asks the service for one' do
      calls = nil

      with_text_properties('description' => 'alt_text') do
        with_stored_annotation({ 'alt_text' => { 'de' => 'Ein Feld voller Lavendel' } }) do
          calls = stub_embedding(ANNOTATION) do
            post focus_point_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
          end
        end
      end

      assert_response :success
      assert_equal 1, calls.size
      assert_equal({ 'x' => 0.25, 'y' => 0.75 }, response.parsed_body['focus_point'])
    end

    test 'it works for an asset that has no content yet' do
      asset = upload_image('test_rgb.jpeg')
      calls = nil

      with_text_properties('description' => 'alt_text') do
        calls = stub_embedding(ANNOTATION) do
          post description_suggestion_things_path, params: { asset_id: asset.id, template_name: TEMPLATE_NAME }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      assert_equal asset.public_url, calls.first[:image_url]
      assert_predicate response.parsed_body.dig('texts', 'description'), :present?
    end

    test 'the image url is derived from the asset, never from the request' do
      asset = upload_image('test_rgb.jpeg')
      calls = nil

      with_text_properties('description' => 'alt_text') do
        calls = stub_embedding(ANNOTATION) do
          post description_suggestion_things_path, params: {
            asset_id: asset.id,
            template_name: TEMPLATE_NAME,
            image_url: 'https://attacker.example.org/expensive.jpg'
          }, headers: JSON_HEADERS
        end
      end

      assert_equal asset.public_url, calls.first[:image_url]
    end

    test 'a language the request did not ask for is not offered' do
      with_text_properties('description' => 'alt_text') do
        stub_embedding({ 'alt_text' => { 'de' => 'Ein Feld voller Lavendel', 'it' => 'Un campo di lavanda' } }) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      # the service answers 'it' whenever an earlier request asked for it and the answer is still
      # cached; the editor being filled is German either way
      assert_equal({ 'de' => 'Ein Feld voller Lavendel' }, response.parsed_body.dig('texts', 'description'))
    end

    test 'an enabled service answering with nothing is reported as an outage, not as a missing feature' do
      with_text_properties('description' => 'alt_text') do
        DataCycleCore::Feature['Embedding'].stub(:embedding, ->(**) { {} }) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_response :unprocessable_content
      assert_equal I18n.t('validation.errors.embedding_endpoint_error', locale: :de), response.parsed_body['error']
    end

    test 'an annotation the service shaped differently answers empty instead of failing' do
      with_text_properties('description' => 'alt_text') do
        stub_embedding(['not', 'a', 'hash']) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      assert_empty response.parsed_body['texts']
    end

    test 'markup in a suggestion is stripped before it reaches an editor' do
      with_text_properties('description' => 'alt_text') do
        stub_embedding({ 'alt_text' => { 'de' => '<img src=x onerror="alert(1)">Ein Feld voller Lavendel' } }) do
          post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
        end
      end

      assert_response :success
      # the rich text editor's import pastes what it is given as HTML, so the service's answer must
      # never carry markup
      assert_equal({ 'de' => 'Ein Feld voller Lavendel' }, response.parsed_body.dig('texts', 'description'))
    end

    test 'it suggests nothing for an attribute the user may not edit' do
      with_text_properties('description' => 'alt_text') do
        DataCycleCore::Feature::ImageDescriptionPixie.stub(:attribute_editable?, ->(*) { false }) do
          stub_embedding(ANNOTATION) do
            post description_suggestion_things_path, params: { thing_id: @content.id }, headers: JSON_HEADERS
          end
        end
      end

      assert_response :success
      assert_empty response.parsed_body['texts']
    end

    test 'the edit form renders a generate button on every opted-in attribute' do
      with_text_properties('description' => 'alt_text', 'name' => 'title', 'caption' => 'captions') do
        get edit_thing_path(@content)
      end

      assert_response :success
      # description is a text editor, name and caption are plain string fields -- both toolbars carry
      # the button
      assert_select 'button.image-description-pixie-button[data-attribute-key=?]', 'description', 1
      assert_select 'button.image-description-pixie-button[data-attribute-key=?]', 'name', 1
      assert_select 'button.image-description-pixie-button[data-attribute-key=?]', 'caption', 1
      assert_select 'button.image-description-pixie-button[data-thing-id=?]', @content.id
    end

    test 'the edit form renders no button for an attribute that did not opt in' do
      with_text_properties('description' => 'alt_text') do
        get edit_thing_path(@content)
      end

      assert_response :success
      assert_select 'button.image-description-pixie-button[data-attribute-key=?]', 'description', 1
      assert_select 'button.image-description-pixie-button[data-attribute-key=?]', 'caption', 0
    end

    test 'it refuses a non-image template' do
      post description_suggestion_things_path, params: { asset_id: upload_image('test_rgb.jpeg').id, template_name: NON_IMAGE_TEMPLATE_NAME }, headers: JSON_HEADERS

      assert_response :unauthorized
    end

    test 'it refuses an unknown asset' do
      post description_suggestion_things_path, params: { asset_id: SecureRandom.uuid, template_name: TEMPLATE_NAME }, headers: JSON_HEADERS

      assert_response :not_found
    end
  end
end
