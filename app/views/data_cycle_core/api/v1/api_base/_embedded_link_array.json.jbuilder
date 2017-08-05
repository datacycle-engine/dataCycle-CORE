json.set! name.pluralize do
  json.array!(data) do |data_item|
    json.partial! definition['type_name'].singularize, object: Object.const_get("DataCycleCore::#{definition['type_name'].singularize.camelize}").send('find', data_item)
  end
end
