json.set! '@context', 'http://schema.org/CreativeWork'
json.set! 'id', content.id
json.set! 'creative_work_id', content.creative_work_id
json.set! 'contentType', content.metadata.dig('validation').dig('name')
json.set! 'deleted_at', content.deleted_at