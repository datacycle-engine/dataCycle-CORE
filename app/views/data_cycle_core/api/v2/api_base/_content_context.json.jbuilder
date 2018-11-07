# frozen_string_literal: true

json.set! '@context', 'http://schema.org'
json.set! '@type', content.schema.dig('api', 'type') || content.try(:schema_type) || content.class.name.demodulize
json.set! 'contentType', content.template_name
