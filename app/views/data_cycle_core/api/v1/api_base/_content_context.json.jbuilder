if content.is_a?(DataCycleCore::CreativeWork)
  json.set! '@context', "http://schema.org/CreativeWork"
elsif content.is_a?(DataCycleCore::Person)
  json.set! '@context', "http://schema.org/Person"
elsif content.is_a?(DataCycleCore::Place)
  json.set! '@context', "http://schema.org/Place"
else
  raise "UnkownContentType"
end
