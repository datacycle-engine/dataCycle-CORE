# type = content.metadata['validation']['description']
# TODO: make proper conversion template_name -> schema.org type
type = content.class.table_name.singularize

json.set! '@context', "http://schema.org/#{type}"
json.set! 'contentType', content.template_name
