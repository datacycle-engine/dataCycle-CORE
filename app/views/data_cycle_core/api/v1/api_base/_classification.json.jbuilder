# frozen_string_literal: true

json.set! 'id', classification.id
json.set! 'name', classification.name || classification.try(:internal_name)
