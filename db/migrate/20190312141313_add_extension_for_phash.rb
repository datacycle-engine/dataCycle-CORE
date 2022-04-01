# frozen_string_literal: true

class AddExtensionForPhash < ActiveRecord::Migration[5.1]
  def change
    # https://github.com/PixNyanNyan/postgres-phash-hamming
    enable_extension 'pg_phash' unless extension_enabled?('pg_phash')
  end
end
