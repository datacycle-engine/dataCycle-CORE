if object.is_a?(DataCycleCore::CreativeWork)
  json.set! '@context', "http://schema.org/CreativeWork"
elsif object.is_a?(DataCycleCore::Place)
  json.set! '@context', "http://schema.org/Place"
elsif object.is_a?(DataCycleCore::Person)
  json.set! '@context', "http://schema.org/Person"
else
  raise NotImplemented
end

if !defined?(nested) || !nested
  json.set! 'id', object.id
  json.set! 'dateCreated', object.created_at
  json.set! 'dateModified', object.updated_at
  json.set! 'url', send("#{object.class.class_name.tableize.singularize}_url", object)
end
