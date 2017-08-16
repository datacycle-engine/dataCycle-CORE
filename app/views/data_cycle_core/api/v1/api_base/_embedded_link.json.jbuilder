if data
  json.set! name do
    json.partial! definition['type_name'].singularize, object: Object.const_get("DataCycleCore::#{definition['type_name'].singularize.camelize}").send('find', data)
  end
end
