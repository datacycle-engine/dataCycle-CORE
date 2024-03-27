# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @es_id = ExternalSystem.first.id
      @ca = ClassificationAlias.create(name: SecureRandom.hex(10), description: SecureRandom.hex(20), external_source_id: @es_id)
    end

    test 'concept gets created from classification_alias' do
      concept = Concept.find(@ca.id)

      assert_equal @ca.name, concept.name
      assert_equal @ca.description, concept.description
      assert_equal @ca.external_source_id, concept.external_system_id
    end

    test 'concept gets updated from classification_alias' do
      @ca.update(name: SecureRandom.hex(10))
      concept = Concept.find(@ca.id)

      assert_equal @ca.name, concept.name
      assert_equal @ca.description, concept.description
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
  end
end
