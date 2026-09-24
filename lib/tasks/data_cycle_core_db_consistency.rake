# frozen_string_literal: true

require 'rake_helpers/db_helper'

namespace :data_cycle_core do
  namespace :db do
    desc 'perform consistency checks on the db'
    task consistency: :environment do
      # check concept_contents
      DbHelper.status_relation(
        DataCycleCore::ConceptContent.where.missing(:concept).count,
        'ConceptContent',
        'concept_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptContent.left_joins(:content_data).where(things: { id: nil }).count,
        'ConceptContent',
        'content_data_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptContent.where(concept_id: nil).count,
        'ConceptContent',
        'concept_id IS NULL '
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptContent.where(content_data_id: nil).count,
        'ConceptContent',
        'content_data_id IS NULL '
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.where(content_a_id: nil).count,
        'ContentContent',
        'content_a_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.where(content_b_id: nil).count,
        'ContentContent',
        'content_b_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.left_joins(:content_a).where(things: { id: nil }).count,
        'ContentContent',
        'content_a_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ContentContent.left_joins(:content_b).where(things: { id: nil }).count,
        'ContentContent',
        'content_b_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptContent.where(content_data_id: nil).count,
        'ConceptContent',
        'content_data_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::Thing.where('things.external_source_id IS NOT NULL AND things.external_source_id NOT IN (SELECT id FROM external_systems)').count,
        'DataCycleCore::Thing',
        'external_source_id valid'
      )
      DbHelper.status_relation(
        DataCycleCore::ExternalSystemSync.joins("LEFT JOIN things ON things.id = external_system_syncs.syncable_id AND external_system_syncs.syncable_type = 'DataCycleCore::Thing'").where(things: { id: nil }).count,
        'ExternalSystemSync',
        'syncable_id (things)'
      )

      DbHelper.status_relation(
        DataCycleCore::Concept.where('concepts.external_system_id IS NOT NULL AND concepts.external_system_id NOT IN (SELECT id FROM external_systems)').count,
        'Concept',
        'external_system_id valid'
      )
      DbHelper.status_relation(
        DataCycleCore::Concept.where('concepts.concept_scheme_id NOT IN (SELECT id FROM concept_schemes)').count,
        'Concept',
        'concept_scheme_id'
      )
      DbHelper.status_relation(
        DataCycleCore::Concept.where(concept_scheme_id: nil).count,
        'Concept',
        'concept_scheme_id IS NULL'
      )
      # every concept is reachable through exactly one `broader` link, so one without is as broken as
      # a dangling one (see DataCycleCore::ConceptLink)
      DbHelper.status_relation(
        DataCycleCore::Concept.where.missing(:parent_concept_link).count,
        'Concept',
        'broader link'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptLink.where('concept_links.child_id NOT IN (SELECT id FROM concepts)').count,
        'ConceptLink',
        'child_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptLink.where(child_id: nil).count,
        'ConceptLink',
        'child_id IS NULL'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptLink.where('concept_links.parent_id IS NOT NULL AND concept_links.parent_id NOT IN (SELECT id FROM concepts)').count,
        'ConceptLink',
        'parent_id'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptLink.where.not(link_type: DataCycleCore::ConceptLink::LINK_TYPES).count,
        'ConceptLink',
        'link_type'
      )
      DbHelper.status_relation(
        DataCycleCore::ConceptScheme.where('concept_schemes.external_system_id IS NOT NULL AND concept_schemes.external_system_id NOT IN (SELECT id FROM external_systems)').count,
        'ConceptScheme',
        'external_system_id valid'
      )
    end
  end
end
