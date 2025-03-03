# frozen_string_literal: true

module DataCycleCore
  class ConceptSchemeLinkJob < ConceptSchemeUnlinkJob
    KEY = 'link'
    METHOD_NAME = :mapped_concepts_to_property
    LINK_TYPE = 'related'
  end
end
