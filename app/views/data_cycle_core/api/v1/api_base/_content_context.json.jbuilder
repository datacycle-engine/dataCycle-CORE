type = content.metadata['validation']['description']

json.set! '@context', "http://schema.org/#{type}"
json.set! 'contentType', content.content_type
