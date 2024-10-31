# frozen_string_literal: true

json.set! '@context', 'http://schema.org/CreativeWork'
json.set! 'creative_work_id', content.creative_work_id
json.set! 'contentType', content.schema['name']
json.set! 'deleted_at', content.deleted_at
