# Load the Rails application.
require_relative 'application'

Time::DATE_FORMATS[:german_date_format] = '%d.%m.%Y'
Time::DATE_FORMATS[:german_datetime_format] = '%d.%m.%Y, %H:%M Uhr'

# Initialize the Rails application.
Rails.application.initialize!
