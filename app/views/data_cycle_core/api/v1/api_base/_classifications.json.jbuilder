# frozen_string_literal: true

json.classifications do
  json.array!(concepts) do |concept|
    json.cache!(concept, expires_in: 10.minutes) do
      json.id concept.id
      json.name concept.name || concept.internal_name
      json.createdAt concept.created_at
      json.updatedAt concept.updated_at
      deleted_at = concept.try(:deleted_at)
      json.deletedAt deleted_at if deleted_at

      json.ancestors do
        json.array!(concept.ancestors_with_concept_scheme) do |ancestor|
          json.id ancestor.id
          json.name ancestor.name || ancestor.try(:internal_name)
          json.createdAt ancestor.created_at
          json.updatedAt ancestor.updated_at
          ancestor_deleted_at = ancestor.try(:deleted_at)
          json.deletedAt ancestor_deleted_at if ancestor_deleted_at
        end
      end
    end
  end
end
