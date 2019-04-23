# frozen_string_literal: true

json.set! '@type', definition.dig('api', 'type') if definition.dig('api', 'type').present?
