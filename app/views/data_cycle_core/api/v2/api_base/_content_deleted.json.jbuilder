# frozen_string_literal: true

json.set! '@context', 'http://schema.org'
json.set! '@type', content.api_type
json.set! 'contentType', content.template_name
json.set! 'content_id', content.thing_id
# TODO: remove creative_work_id (check for Gemeindeportale)
json.set! 'creative_work_id', content.thing_id
json.set! 'deleted_at', content.deleted_at
