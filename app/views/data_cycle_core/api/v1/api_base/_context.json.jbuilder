if object.is_a?(DataCycleCore::CreativeWork)
  json.set! '@context', "http://schema.org/CreativeWork"
elsif object.is_a?(DataCycleCore::Person)
  json.set! '@context', "http://schema.org/Person"
elsif object.is_a?(DataCycleCore::Place)
  json.set! '@context', "http://schema.org/Place"
else
  raise "UnkownContentType"
end
