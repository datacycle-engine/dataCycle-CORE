default_options = {
  header_type: :full,
  classifications: true
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.content_partial! 'context', content: content

case options[:header_type]
  when :full
    json.set! 'id', content.id
    json.set! 'dateCreated', content.created_at
    json.set! 'dateModified', content.updated_at
    json.set! 'url', send("#{content.class.class_name.tableize.singularize}_url", content)
    json.set! 'classifications' do
      json.array! content.classifications, partial: 'classification', as: :classification
    end
  else
    json.set! 'id', content.id
end
