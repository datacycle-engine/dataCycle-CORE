# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      # [#50050] End-to-end coverage of the from_linked compute wired into a template: the degree of
      # AI involvement of the linked ArtificialIntelligenceAgent contents, mirrored onto the content
      # itself so it is stored, filterable and delivered in dc:classification.
      class ComputedFromLinkedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        GENERATED = 'odta:AIGenerated'
        MODIFIED = 'odta:AIModified'

        def concept_for(degree)
          DataCycleCore::Concept
            .for_tree(DataCycleCore::AiAgentService::CONCEPT_SCHEME)
            .find_by!(external_key: degree)
        end

        def agent_for(degree)
          DataCycleCore::AiAgentService.find_or_create(
            DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference.new(degree, nil)
          )
        end

        def create_image(contributor_ids)
          DataCycleCore::TestPreparations.create_content(
            template_name: 'FromLinked-Image',
            data_hash: { 'name' => 'From Linked Test', 'contributor' => Array.wrap(contributor_ids) }
          )
        end

        def degree_ids(content)
          Array.wrap(content.reload.get_data_hash['dc_ai_degree_of_involvement'])
        end

        test 'collects the degree of involvement of the linked agent' do
          image = create_image(agent_for(GENERATED).id)

          assert_equal [concept_for(GENERATED).classification_id], degree_ids(image)
        end

        test 'collects the degree of every linked agent' do
          image = create_image([agent_for(GENERATED).id, agent_for(MODIFIED).id])

          assert_equal(
            [concept_for(GENERATED).classification_id, concept_for(MODIFIED).classification_id].sort,
            degree_ids(image).sort
          )
        end

        test 'collects a degree shared by two linked agents only once' do
          named = DataCycleCore::AiAgentService.find_or_create(
            DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference.new(GENERATED, 'Opus 5')
          )
          image = create_image([agent_for(GENERATED).id, named.id])

          assert_equal [concept_for(GENERATED).classification_id], degree_ids(image)
        end

        test 'collects nothing without a linked content' do
          assert_empty degree_ids(create_image([]))
        end

        # from_linked reads the classifications of the linked contents, filtered to its own
        # tree_label - a contributor that is an organization, not an agent, adds no degree
        test 'collects only the concepts of its own tree' do
          tagged = DataCycleCore::TestPreparations.create_content(
            template_name: 'FromLinked-Tagged',
            data_hash: { 'name' => 'Not An Agent', 'tags' => [DataCycleCore::Concept.for_tree('Tags').find_by!(name: 'Tag 1').classification_id] }
          )

          assert_empty degree_ids(create_image(tagged.id))
        end

        test 'unsets the degree when the agent is unlinked again' do
          image = create_image(agent_for(GENERATED).id)

          image.set_data_hash(data_hash: { 'contributor' => [] })

          assert_empty degree_ids(image)
        end

        test 'updates the degree when another agent is linked' do
          image = create_image(agent_for(GENERATED).id)

          image.set_data_hash(data_hash: { 'contributor' => [agent_for(MODIFIED).id] })

          assert_equal [concept_for(MODIFIED).classification_id], degree_ids(image)
        end

        # a template error must not clear what is stored, unlike an empty result - asserted against
        # the stored value, not just the return value
        test 'keeps the stored value when the property has no tree_label' do
          image = create_image(agent_for(GENERATED).id)
          stored = degree_ids(image)

          assert_equal [concept_for(GENERATED).classification_id], stored

          computed = DataCycleCore::Utility::Compute::Classification.from_linked(
            computed_parameters: { 'contributor' => [agent_for(GENERATED).id] },
            computed_definition: { 'compute' => { 'method' => 'from_linked' } },
            content: image,
            key: 'dc_ai_degree_of_involvement'
          )

          assert_equal stored, computed
        end

        # the counterpart: an empty result does clear it, which is why the two must differ
        test 'clears the stored value when nothing is linked any more' do
          image = create_image(agent_for(GENERATED).id)

          computed = DataCycleCore::Utility::Compute::Classification.from_linked(
            computed_parameters: { 'contributor' => [] },
            computed_definition: { 'tree_label' => DataCycleCore::AiAgentService::CONCEPT_SCHEME, 'compute' => { 'method' => 'from_linked' } },
            content: image,
            key: 'dc_ai_degree_of_involvement'
          )

          assert_equal [], computed
        end
      end
    end
  end
end
