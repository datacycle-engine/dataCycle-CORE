class_hash = { "classification_aliases" => []}
image.classification_aliases.each do |class_item|
  class_hash["classification_aliases"].push({"@id" => class_item.id, name: class_item.name})
end

data_hash = {
  "@context" => "http://www.schema.org/ImageObject",
  "@id" => image.id,
}.merge!(class_hash)
data_hash.merge!(image.get_data_hash.compact)
json.set! language, data_hash
