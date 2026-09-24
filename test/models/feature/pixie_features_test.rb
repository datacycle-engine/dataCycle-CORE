# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # The two dataPixie frontend features are pure composition layers over backend features that live
  # in separate plugin gems (content_classifier, embedding), neither of which is loaded in
  # data-cycle-core's standalone test environment. Both are reached exclusively through
  # Feature::Base#dependencies_*, so the tests stub the dependency verdict rather than the gems.
  class PixieFeaturesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    CLASSIFICATION_PIXIE = DataCycleCore::Feature::ClassificationPixie
    ANNOTATION_PIXIE = DataCycleCore::Feature::AnnotationPixie
    DESCRIPTION_PIXIE = DataCycleCore::Feature::ImageDescriptionPixie

    IMAGE_TEMPLATE = 'Bild'
    VIDEO_TEMPLATE = 'Video'
    PDF_TEMPLATE = 'PDF'

    def image_content
      DataCycleCore::Thing.new(template_name: IMAGE_TEMPLATE)
    end

    # Runs the block with the feature reporting an enabled + allowed configuration and the given
    # verdict for its backend dependencies.
    def with_feature(feature, dependencies_allowed: true, configuration: {}, &)
      feature.stub(:enabled?, true) do
        feature.stub(:configuration, ->(*) { { 'allowed' => true }.merge(configuration) }) do
          feature.stub(:dependencies_allowed?, ->(*) { dependencies_allowed }, &)
        end
      end
    end

    # --- ClassificationPixie ------------------------------------------------

    test 'ClassificationPixie is allowed only while its backend features are allowed' do
      with_feature(CLASSIFICATION_PIXIE) do
        assert_predicate CLASSIFICATION_PIXIE, :allowed?
      end

      with_feature(CLASSIFICATION_PIXIE, dependencies_allowed: false) do
        assert_not CLASSIFICATION_PIXIE.allowed?
      end
    end

    test 'ClassificationPixie is not allowed when its own configuration disallows it' do
      with_feature(CLASSIFICATION_PIXIE, configuration: { 'allowed' => false }) do
        assert_not CLASSIFICATION_PIXIE.allowed?
      end
    end

    # --- AnnotationPixie ----------------------------------------------------

    test 'AnnotationPixie exposes its controller and routes modules' do
      assert_kind_of Module, ANNOTATION_PIXIE.controller_module
      assert_kind_of Module, ANNOTATION_PIXIE.routes_module
    end

    test 'AnnotationPixie is allowed only for image contents' do
      with_feature(ANNOTATION_PIXIE) do
        assert ANNOTATION_PIXIE.allowed?(image_content)
        assert_not ANNOTATION_PIXIE.allowed?(DataCycleCore::Thing.new(template_name: VIDEO_TEMPLATE))
        assert_not ANNOTATION_PIXIE.allowed?(DataCycleCore::Thing.new(template_name: PDF_TEMPLATE))
        assert_not ANNOTATION_PIXIE.allowed?(nil)
      end
    end

    test 'AnnotationPixie is not allowed while a backend feature is missing' do
      with_feature(ANNOTATION_PIXIE, dependencies_allowed: false) do
        assert_not ANNOTATION_PIXIE.allowed?(image_content)
      end
    end

    # The rules that used to sit in the two controllers. Each is pure -- a clamp, a slice, a first
    # non-blank url -- and needed a full integration request to exercise before.
    test 'AnnotationPixie clamps a suggested focus point into the fractions the editor stores' do
      # the editor's own #calculateCrossHairPosition keeps the crosshair inside the image, so an
      # unclamped x = 1.4 would show a point on the right edge and persist one 40% past it
      assert_equal({ 'x' => 1.0, 'y' => 0.0 }, ANNOTATION_PIXIE.focus_point_from({ 'focus_point' => { 'x' => 1.4, 'y' => -0.2 } }))
      assert_equal({ 'x' => 0.25, 'y' => 0.75 }, ANNOTATION_PIXIE.focus_point_from({ 'focus_point' => { 'x' => '0.25', 'y' => '0.75' } }))
    end

    test 'AnnotationPixie reads no focus point from an answer that carries none' do
      # a missing or incomplete point is a valid answer, not an error
      assert_nil ANNOTATION_PIXIE.focus_point_from({})
      assert_nil ANNOTATION_PIXIE.focus_point_from({ 'focus_point' => nil })
      assert_nil ANNOTATION_PIXIE.focus_point_from({ 'focus_point' => { 'x' => 0.5 } })
      assert_nil ANNOTATION_PIXIE.focus_point_from({ 'focus_point' => { 'x' => 'links', 'y' => 'oben' } })
      assert_nil ANNOTATION_PIXIE.focus_point_from(nil)
    end

    test 'the image url is the first absolute one, asset before the content own properties' do
      asset = Struct.new(:public_url).new('https://dc.example.org/assets/image/x/original/madrisa.jpg')
      imported = DataCycleCore::Thing.new(template_name: IMAGE_TEMPLATE)

      assert_equal asset.public_url, ANNOTATION_PIXIE.image_url(imported, asset)
      # an imported image (Wikidata's, Canto's) carries no asset at all
      assert_nil ANNOTATION_PIXIE.image_url(imported, nil)
      # a relative url is what Asset#public_url answers with while asset_host is unset, and the
      # service could never fetch it -- the empty answer would then be cached for three days
      assert_nil ANNOTATION_PIXIE.image_url(imported, Struct.new(:public_url).new('/assets/image/x/original/madrisa.jpg'))
    end

    test 'the annotations of a result that carries none are an empty hash' do
      assert_equal({ 'alt_text' => { 'de' => 'Lavendel' } }, ANNOTATION_PIXIE.annotation_data({ 'data' => { 'alt_text' => { 'de' => 'Lavendel' } } }))
      assert_empty ANNOTATION_PIXIE.annotation_data({ 'data' => nil })
      assert_empty ANNOTATION_PIXIE.annotation_data({})
    end

    test 'AnnotationPixie delegates tree eligibility to the content classifier content module' do
      user = DataCycleCore::User.new
      properties = [{ 'concept_scheme_name' => 'Zielgruppen', 'property_key' => 'universal_classifications', 'concept_scheme_id' => 'scheme-id' }]
      content = image_content
      content.define_singleton_method(:allowed_properties_for_user) { |_user| properties }

      assert_equal properties, ANNOTATION_PIXIE.eligible_properties(content, user)
    end

    test 'AnnotationPixie reports no eligible trees without the content classifier feature' do
      assert_empty ANNOTATION_PIXIE.eligible_properties(image_content, DataCycleCore::User.new)
      assert_empty ANNOTATION_PIXIE.eligible_properties(nil, DataCycleCore::User.new)
      assert_empty ANNOTATION_PIXIE.eligible_properties(image_content, nil)
    end

    test 'AnnotationPixie splits eligible trees into dedicated and universal properties' do
      user = DataCycleCore::User.new
      content = image_content
      properties = [
        { 'concept_scheme_name' => 'Tags', 'property_key' => 'tags', 'concept_scheme_id' => 'tags-id' },
        { 'concept_scheme_name' => 'Zielgruppen', 'property_key' => 'universal_classifications', 'concept_scheme_id' => 'target-id' }
      ]
      content.define_singleton_method(:allowed_properties_for_user) { |_user| properties }

      # 'tags' carries tree_label 'Tags' in the test data definition -> its own editor already
      # renders it, so the pixie must only render the tree without a dedicated attribute.
      assert_equal [properties.second], ANNOTATION_PIXIE.undedicated_properties(content, user)
      assert ANNOTATION_PIXIE.dedicated_property?(content, properties.first)
      assert_not ANNOTATION_PIXIE.dedicated_property?(content, properties.second)
    end

    # --- ImageDescriptionPixie ----------------------------------------------

    # Property definitions as a template would carry them, so the per-property :features: layer of
    # Feature::Base#configuration is what the pixie is read out of -- the same wiring the focus
    # point editor uses.
    def content_with_text_properties(properties)
      content = image_content
      schema = content.schema.deep_dup
      properties.each { |key, definition| schema['properties'][key] = definition }
      content.define_singleton_method(:schema) { schema }
      content
    end

    def opted_in(source)
      { 'label' => 'Beschreibung', 'type' => 'string', 'features' => { 'image_description_pixie' => { 'allowed' => true, 'source' => source } } }
    end

    test 'ImageDescriptionPixie exposes its controller and routes modules' do
      assert_kind_of Module, DESCRIPTION_PIXIE.controller_module
      assert_kind_of Module, DESCRIPTION_PIXIE.routes_module
    end

    test 'ImageDescriptionPixie is allowed only for image contents with its backend feature' do
      with_feature(DESCRIPTION_PIXIE) do
        assert DESCRIPTION_PIXIE.allowed?(image_content)
        assert_not DESCRIPTION_PIXIE.allowed?(DataCycleCore::Thing.new(template_name: VIDEO_TEMPLATE))
        assert_not DESCRIPTION_PIXIE.allowed?(nil)
      end

      with_feature(DESCRIPTION_PIXIE, dependencies_allowed: false) do
        assert_not DESCRIPTION_PIXIE.allowed?(image_content)
      end
    end

    test 'ImageDescriptionPixie collects the attributes a template opts in' do
      content = content_with_text_properties('description' => opted_in('alt_text'), 'caption' => opted_in('captions'))

      # order follows the template's property order, not the order they were opted in
      assert_equal ['caption', 'description'], DESCRIPTION_PIXIE.attribute_keys(content).sort
      assert_equal 'alt_text', DESCRIPTION_PIXIE.source_for(content, 'description')
      assert_equal 'captions', DESCRIPTION_PIXIE.source_for(content, 'caption')
      assert_nil DESCRIPTION_PIXIE.source_for(content, 'name')
    end

    test 'ImageDescriptionPixie reads only the annotation fields that carry text' do
      assert DESCRIPTION_PIXIE.source?('alt_text')
      # a misspelled :source: and one that is not a text field at all: the computed ALT label asks
      # here before it annotates, so neither costs a request for an answer it could not read
      assert_not DESCRIPTION_PIXIE.source?('alttext')
      assert_not DESCRIPTION_PIXIE.source?('focus_point')
      assert_not DESCRIPTION_PIXIE.source?(nil)
      assert_nil DESCRIPTION_PIXIE.source_for(content_with_text_properties('description' => opted_in('alttext')), 'description')
    end

    test 'ImageDescriptionPixie offers a suggestion for the edited locale alone' do
      value = { 'de' => 'Ein Feld voller Lavendel', 'en' => 'A field of lavender' }

      # the editor a wand sits in writes that translation and nothing else, so a suggestion for
      # another locale would have nowhere to go
      assert_equal({ 'de' => 'Ein Feld voller Lavendel' }, DESCRIPTION_PIXIE.suggestion_by_locale(value, 'de'))
      assert_empty DESCRIPTION_PIXIE.suggestion_by_locale(value, 'it')
      # a provider answering with a bare string is offered under the locale that was asked for
      assert_equal({ 'de' => 'Lavendelfeld' }, DESCRIPTION_PIXIE.suggestion_by_locale('Lavendelfeld', 'de'))
      assert_empty DESCRIPTION_PIXIE.suggestion_by_locale(nil, 'de')
    end

    test 'ImageDescriptionPixie strips the markup a service answered with' do
      # one of the editors a suggestion is offered to is a rich text editor, whose import pastes
      # what it is given as HTML
      assert_equal 'Lavendel', DESCRIPTION_PIXIE.plain_text('  <b>Lavendel</b> ')
      assert_equal({ 'de' => 'Berg & Tal' }, DESCRIPTION_PIXIE.suggestion_by_locale({ 'de' => '<p>Berg &amp; Tal</p>' }, 'de'))
      assert_empty DESCRIPTION_PIXIE.suggestion_by_locale({ 'de' => '<br>' }, 'de')
    end

    test 'ImageDescriptionPixie offers only the attributes the user may edit' do
      content = content_with_text_properties('description' => opted_in('alt_text'), 'caption' => opted_in('captions'))
      # #can_attribute?, not #can?: the pixie asks the question the editor asks, through
      # DataAttributeOptions#attribute_allowed? -- see Feature::Concerns::ImageContent
      allowing_user = DataCycleCore::User.new
      allowing_user.define_singleton_method(:can_attribute?) { |*| true }
      denying_user = DataCycleCore::User.new
      denying_user.define_singleton_method(:can_attribute?) { |*| false }

      with_feature(DESCRIPTION_PIXIE, configuration: { 'attribute_keys' => ['description', 'caption'] }) do
        assert_equal ['caption', 'description'], DESCRIPTION_PIXIE.editable_attribute_keys(content, allowing_user).sort
        assert_empty DESCRIPTION_PIXIE.editable_attribute_keys(content, denying_user)
        assert_empty DESCRIPTION_PIXIE.editable_attribute_keys(content, nil)
        assert_empty DESCRIPTION_PIXIE.editable_attribute_keys(nil, allowing_user)
      end
    end

    # An external system the way the content carries it: :generate_for: names systems by name or by
    # identifier, because a project's features.yml is written against its external_sources/*.yml.
    def content_from(name:, identifier:)
      content = image_content
      system = DataCycleCore::ExternalSystem.new(name:, identifier:)
      content.define_singleton_method(:external_source) { system }
      content
    end

    test 'ImageDescriptionPixie generates the computed text for every image while nothing narrows it' do
      with_feature(DESCRIPTION_PIXIE) do
        assert DESCRIPTION_PIXIE.generate?(image_content)
        assert DESCRIPTION_PIXIE.generate?(content_from(name: 'Canto', identifier: 'canto'))
      end

      with_feature(DESCRIPTION_PIXIE, dependencies_allowed: false) do
        assert_not DESCRIPTION_PIXIE.generate?(image_content)
      end
    end

    test 'ImageDescriptionPixie generates the computed text only for the named external systems' do
      scope = { 'generate_for' => { 'external_sources' => ['Canto'] } }

      with_feature(DESCRIPTION_PIXIE, configuration: scope) do
        assert DESCRIPTION_PIXIE.generate?(content_from(name: 'Canto', identifier: 'canto'))
        assert DESCRIPTION_PIXIE.generate?(content_from(name: 'Canto DAM', identifier: 'Canto')), 'the identifier is accepted too'
        assert_not DESCRIPTION_PIXIE.generate?(content_from(name: 'Wikidata', identifier: 'wikidata'))
        # an editorial upload belongs to no import, so a narrowed feature leaves it to the wands
        assert_not DESCRIPTION_PIXIE.generate?(image_content)
        assert_not DESCRIPTION_PIXIE.generate?(nil)
      end
    end

    test 'ImageDescriptionPixie narrowing the computed text leaves the wands untouched' do
      with_feature(DESCRIPTION_PIXIE, configuration: { 'generate_for' => { 'external_sources' => ['Canto'] } }) do
        assert DESCRIPTION_PIXIE.allowed?(image_content), 'the generate buttons stay available everywhere the DESCRIPTION_PIXIE is'
      end
    end

    test 'ImageDescriptionPixie generates in the configured languages, defaulting to the main one' do
      DESCRIPTION_PIXIE.stub(:configuration, ->(*) { {} }) do
        assert_equal [I18n.default_locale.to_s], DESCRIPTION_PIXIE.generate_languages
      end

      # every language is a vision call of its own, so an unconfigured feature pays for one
      DESCRIPTION_PIXIE.stub(:configuration, ->(*) { { 'generate_for' => { 'languages' => ['de', 'en'] } } }) do
        assert_equal ['de', 'en'], DESCRIPTION_PIXIE.generate_languages
      end

      # the languages belong to :generate_for:, so a stray top-level key is not one of them
      DESCRIPTION_PIXIE.stub(:configuration, ->(*) { { 'languages' => ['de', 'en'] } }) do
        assert_equal [I18n.default_locale.to_s], DESCRIPTION_PIXIE.generate_languages
      end
    end

    # --- AnnotationPixie#editor_configuration --------------------------------

    ClassificationStub = Struct.new(:id)

    # Everything editor_configuration reads from the database, stubbed: which concept schemes the
    # content's classifications belong to (Concept), which of the requested schemes hold concepts at
    # all, and the definition each editor renders from -- the content here is a template thing whose
    # universal_classifications are Structs.
    def with_stubbed_schemes(feature, schemes, &)
      feature.stub(:renderable_properties, ->(properties) { properties }) do
        feature.stub(:editor_definition, ->(*) { {} }) do
          DataCycleCore::Concept.stub(:concept_scheme_ids_by_concept, ->(*) { schemes }, &)
        end
      end
    end

    def universal_property(name, scheme_id)
      { 'concept_scheme_name' => name, 'property_key' => 'universal_classifications', 'concept_scheme_id' => scheme_id }
    end

    # content whose universal_classifications hold the given stub classifications
    def content_with_universal_classifications(properties, classifications)
      content = image_content
      content.define_singleton_method(:allowed_properties_for_user) { |_user| properties }
      content.define_singleton_method(:universal_classifications) { classifications }
      content
    end

    test 'AnnotationPixie groups the current classifications of a shared property per tree' do
      properties = [universal_property('Zielgruppen', 'target-scheme'), universal_property('Veranstaltungskategorien', 'event-scheme')]
      classifications = [ClassificationStub.new('target-1'), ClassificationStub.new('event-1'), ClassificationStub.new('other-1')]
      content = content_with_universal_classifications(properties, classifications)
      schemes = { 'target-1' => ['target-scheme'], 'event-1' => ['event-scheme'], 'other-1' => ['unrelated-scheme'] }

      configuration = with_stubbed_schemes(ANNOTATION_PIXIE, schemes) do
        ANNOTATION_PIXIE.editor_configuration(content, DataCycleCore::User.new)
      end

      assert_equal ['target-1'], configuration[:editors].first['classifications'].map(&:id)
      assert_equal ['event-1'], configuration[:editors].second['classifications'].map(&:id)
      # the classification of a tree that gets no editor here must be carried through the save,
      # because set_classification_relation_ids replaces the whole relation
      assert_equal ['other-1'], configuration[:retained]['universal_classifications']
    end

    test 'AnnotationPixie retains a classification whose tree is unknown' do
      properties = [universal_property('Zielgruppen', 'target-scheme')]
      content = content_with_universal_classifications(properties, [ClassificationStub.new('orphan-1')])

      configuration = with_stubbed_schemes(ANNOTATION_PIXIE, {}) do
        ANNOTATION_PIXIE.editor_configuration(content, DataCycleCore::User.new)
      end

      assert_empty configuration[:editors].first['classifications']
      assert_equal ['orphan-1'], configuration[:retained]['universal_classifications']
    end

    test 'AnnotationPixie configures no editors without eligible trees' do
      configuration = ANNOTATION_PIXIE.editor_configuration(image_content, DataCycleCore::User.new)

      assert_empty configuration[:editors]
      assert_empty configuration[:retained]
    end
  end
end
