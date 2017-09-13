json.classifications do
  json.array!(classification_aliases) do |classification_alias|
    json.id classification_alias.id
    json.name classification_alias.name
    json.created_at classification_alias.created_at
    json.updated_at classification_alias.updated_at
    json.deleted_at classification_alias.deleted_at if classification_alias.deleted_at

    json.ancestors do
      json.array!(classification_alias.ancestors) do |ancestor|
        json.id ancestor.id
        json.name ancestor.name
        json.created_at ancestor.created_at
        json.updated_at ancestor.updated_at
        json.deleted_at classification_alias.deleted_at if classification_alias.deleted_at
      end
    end
  end
end
