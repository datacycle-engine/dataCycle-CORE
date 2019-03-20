# frozen_string_literal: true

# Borrowed from Traco

require 'bundler/setup'
require 'benchmark/ips'
require 'active_record'
require 'translations'

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

I18n.enforce_available_locales = false
I18n.available_locales = [:de, :en, :it]
I18n.default_locale = :de
I18n.locale = :en

COLUMNS = [:default, :no_presence, :no_cache].freeze

ActiveRecord::Schema.define(version: 0) do
  create_table :posts, force: true do |t|
    I18n.available_locales.each do |locale|
      t.string "plain_#{locale}"
    end
    COLUMNS.each do |column|
      t.string "#{column}_i18n"
    end
  end
end

class Post < ActiveRecord::Base # rubocop:disable Rails/ApplicationRecord
  extend Translations
  translates :default, column_suffix: '_i18n', backend: :jsonb
  translates :no_presence, column_suffix: '_i18n', backend: :jsonb, presence: false
  translates :no_cache, column_suffix: '_i18n', backend: :jsonb, cache: false
  default_scope { i18n }
end

post = Post.new
post.plain_de = 'Servas'
post.plain_en = 'Hello'
COLUMNS.each do |column|
  I18n.with_locale(:de) { post.send("#{column}=", 'Servas') }
  I18n.with_locale(:en) { post.send("#{column}=", 'Hello') }
end

Benchmark.ips do |x|
  x.report('activerecord') { post.plain_de }
  x.report('mobility with default plugins') { post.default }
  x.report('mobility without presence plugin') { post.no_presence }
  x.report('mobility without cache plugin') { post.no_cache }

  x.compare!
end
