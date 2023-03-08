# frozen_string_literal: true

Mobility.configure do
  plugins do
    active_record
    query

    reader
    writer

    cache
  end
end
