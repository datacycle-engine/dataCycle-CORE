# frozen_string_literal: true

yield if value.present? && definition.dig('api', 'disabled').blank?
