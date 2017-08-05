default_options = {
  header_type: :full,
  classifications: true
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.partial! 'context', object: object

case options[:header_type]
  when :full
    json.set! 'id', object.id
    json.set! 'dateCreated', object.created_at
    json.set! 'dateModified', object.updated_at
    json.set! 'url', send("#{object.class.class_name.tableize.singularize}_url", object)
    json.set! 'classifications' do
      json.array! object.classifications, partial: 'classification', as: :classification
    end
  else
    json.set! 'id', object.id
end
