# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @es_id = ExternalSystem.first.id
      @ca = ClassificationAlias.create(name: SecureRandom.hex(10), description: SecureRandom.hex(20), external_source_id: @es_id)
    end

    test 'concept gets created from classification_alias' do
      assert_equal @ca.name, @ca.concept.name
      assert_equal @ca.description, @ca.concept.description
      assert_equal @ca.external_source_id, @ca.concept.external_system_id
    end

    test 'concept gets updated from classification_alias' do
      @ca.update(name: SecureRandom.hex(10))

      assert_equal @ca.name, @ca.concept.name
      assert_equal @ca.description, @ca.concept.description
    end

    test 'concept gets delete when classification_alias is soft deleted' do
      @ca.destroy

      assert_raise(ActiveRecord::RecordNotFound) do
        Concept.find(@ca.id)
      end
    end

    test 'concept gets delete when classification_alias is really deleted' do
      @ca.destroy_fully!

      assert_raise(ActiveRecord::RecordNotFound) do
        Concept.find(@ca.id)
      end
    end

    test 'create new concept' do
      concept_scheme1 = ConceptScheme.create!(name: 'test')
      concept1 = Concept.create(name: 'test', external_system_id: @es_id, internal: true, concept_scheme: concept_scheme1)

      assert concept1.is_a?(Concept)
      assert_equal 'test', concept1.name
      assert_equal @es_id, concept1.external_system_id
      assert concept1.internal
      assert_equal concept_scheme1.id, concept1.concept_scheme.id
    end

    test 'create new concept with parent' do
      concept_scheme1 = ConceptScheme.create!(name: 'test')
      concept1 = Concept.create(name: 'test', external_system_id: @es_id, internal: true, concept_scheme: concept_scheme1, parent: @ca.concept)

      assert concept1.is_a?(Concept)
      assert_equal 'test', concept1.name
      assert_equal @es_id, concept1.external_system_id
      assert concept1.internal
      assert_equal concept_scheme1.id, concept1.concept_scheme.id
      assert_equal @ca.concept.id, concept1.parent.id
    end

    test 'create accepts an array of attribute hashes' do
      concept_scheme1 = ConceptScheme.create!(name: SecureRandom.hex(8))
      concepts = Concept.create([
                                  { name: 'arr1', external_system_id: @es_id, concept_scheme: concept_scheme1 },
                                  { name: 'arr2', external_system_id: @es_id, concept_scheme: concept_scheme1 }
                                ])

      assert_equal(2, concepts.size)
      assert(concepts.all?(Concept))
    end

    test 'create! creates a concept and accepts arrays' do
      concept_scheme1 = ConceptScheme.create!(name: SecureRandom.hex(8))
      concept = Concept.create!(name: 'bang', external_system_id: @es_id, internal: true, concept_scheme: concept_scheme1)

      assert(concept.is_a?(Concept))
      assert_equal('bang', concept.name)

      concepts = Concept.create!([{ name: 'bang_arr', external_system_id: @es_id, concept_scheme: concept_scheme1 }])

      assert_equal(1, concepts.size)
    end

    test 'readonly? is always true' do
      assert_predicate @ca.concept, :readonly?
    end

    test 'order_by_similarity builds a similarity-ordered relation' do
      assert_nothing_raised { Concept.order_by_similarity('tag').limit(1).to_a }
    end

    test 'class-level classifications and classification_polygons scope by the relation' do
      assert_kind_of(ActiveRecord::Relation, Concept.for_tree('Tags').classifications)
      assert_kind_of(ActiveRecord::Relation, Concept.for_tree('Tags').classification_polygons)
    end

    test 'ancestors returns the ancestor concepts of a tree concept' do
      tag_concept = ClassificationAlias.for_tree('Tags').first.concept

      assert_predicate tag_concept.classification_alias_path, :present?
      assert_kind_of(Array, tag_concept.ancestors.to_a)
    end

    test 'to_api_default_values and to_hash expose identity attributes' do
      concept = @ca.concept

      assert_equal(concept.id, concept.to_api_default_values['@id'])
      assert_equal('skos:Concept', concept.to_api_default_values['@type'])
      assert_equal('DataCycleCore::Concept', concept.to_hash['class_type'])
    end

    test 'color and color? read the ui_configs color' do
      concept = @ca.concept

      assert_nil concept.color
      assert_not concept.color?
    end

    test 'icon returns nil without a configured icon and the asset url with one' do
      concept = @ca.concept

      assert_nil concept.icon
      assert_not concept.icon?

      view_helpers = Class.new { def dc_image_url(path) = "/assets/#{path}" }.new

      DataCycleCore.stub(:classification_icons, { concept.id => 'star.svg' }) do
        DataCycleCore::LocalizationService.stub(:view_helpers, view_helpers) do
          assert_equal('/assets/icons/star.svg', concept.icon)
        end
      end
    end

    test 'to_sync_data serializes a concept and the class scope maps over many' do
      assert_not_nil @ca.concept.to_sync_data
      assert_kind_of(Array, Concept.for_tree('Tags').to_sync_data)
    end

    test 'parent_id and external_system_identifier delegate to associations' do
      assert_nil @ca.concept.parent_id
      assert_equal(ExternalSystem.find(@es_id).identifier, @ca.concept.external_system_identifier)
    end

    test 'validate_color_format rejects non-hex colors' do
      concept = @ca.concept
      concept.ui_configs = { 'color' => 'not-a-hex' }
      concept.valid?

      assert(concept.errors.added?(:ui_configs, :color_format))
    end

    test 'set_internal_name derives the internal name from the changed name' do
      concept = @ca.concept
      concept.name = 'changed concept name'
      concept.valid?

      assert_equal('changed concept name', concept.internal_name)
    end
  end
end
