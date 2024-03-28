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
      assert_equal true, concept1.internal
      assert_equal concept_scheme1.id, concept1.concept_scheme.id
    end

    test 'create new concept with parent' do
      concept_scheme1 = ConceptScheme.create!(name: 'test')
      concept1 = Concept.create(name: 'test', external_system_id: @es_id, internal: true, concept_scheme: concept_scheme1, parent: @ca.concept)

      assert concept1.is_a?(Concept)
      assert_equal 'test', concept1.name
      assert_equal @es_id, concept1.external_system_id
      assert_equal true, concept1.internal
      assert_equal concept_scheme1.id, concept1.concept_scheme.id
      assert_equal @ca.concept.id, concept1.parent.id
    end
  end
end
