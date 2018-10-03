# frozen_string_literal: true

json.set! key do
  json.array!(classification_aliases) do |classification_alias|
    json.cache!(classification_alias, expires_in: 10.minutes) do
      json.id classification_alias.id
      json.name classification_alias.name
      json.description classification_alias.description if classification_alias.description.present?
      json.createdAt classification_alias.created_at
      json.updatedAt classification_alias.updated_at
      json.deletedAt classification_alias.deleted_at if classification_alias.deleted_at

      json.ancestors do
        json.array!(classification_alias.ancestors) do |ancestor|
          json.id ancestor.id
          json.name ancestor.name
          json.createdAt ancestor.created_at
          json.updatedAt ancestor.updated_at
          json.deletedAt classification_alias.deleted_at if classification_alias.deleted_at
        end
      end
    end
  end
end
