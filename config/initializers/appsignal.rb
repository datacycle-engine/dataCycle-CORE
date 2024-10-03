# frozen_string_literal: true

Appsignal.configure do |config|
  config.ignore_errors = (Array.wrap(config.ignore_errors) + [
    'DataCycleCore::Error::RecordNotFoundError',
    'DataCycleCore::Error::Api::InvalidArgumentError',
    'ActionController::BadRequest',
    'ActiveRecord::RecordNotFound',
    'ActionController::RoutingError'
  ]).uniq
end
