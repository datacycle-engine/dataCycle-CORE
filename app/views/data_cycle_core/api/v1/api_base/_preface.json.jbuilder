if object.is_a?(DataCycleCore::CreativeWork)
  json.set! '@context', "http://www.schema.org/CreativeWork"
elsif object.is_a?(DataCycleCore::Place)
  json.set! '@context', "http://www.schema.org/Place"
else
  raise NotImplemented
end

json.set! 'id', object.id
json.set! 'dateCreated', object.created_at
json.set! 'dateModified', object.updated_at
