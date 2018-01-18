default_options = {
  header_type: :full,
  classifications: true
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.content_partial! 'context', content: content

json.set! '@id', content.id
json.set! 'identifier', send("#{content.class.class_name.tableize.singularize}_url", content)

if options[:header_type] == :full
  json.set! 'dateCreated', content.created_at
  json.set! 'dateModified', content.updated_at

  json.set! 'datePublished', content.metadata['validity_period']['date_published'] || content.metadata['validity_period']['valid_from'] if content.metadata['validity_period'] && (content.metadata['validity_period']['date_published'] || content.metadata['validity_period']['valid_from'])
  json.set! 'expires', content.metadata['validity_period']['expires'] || content.metadata['validity_period']['valid_until'] if content.metadata['validity_period'] && (content.metadata['validity_period']['expires'] || content.metadata['validity_period']['valid_until'])

  json.set! 'url', send("#{content.class.class_name.tableize.singularize}_url", content)

  json.set! 'classifications' do
    json.array! content.classifications, partial: 'classification', as: :classification
  end
end
