# frozen_string_literal: true

Mobility.configure do
  plugins do
    active_record
    query

    reader
    writer

    cache

    attribute_methods
  end
end
