# Translation gem

At the moment this gem supports two backends:
1. jsonb (translates each individual field in a separete jsonb field)
2. table (translates all field in a separate translations table)

## Configuration:

Set the default options in the initialize folder of Rails.
```
Translations.configure do |config|
  config.plugins(:query)
end
```
optional configurations:
```
config.default_backend = :jsonb
config.accessor_method = :translates
config.query_method    = :i18n
```

## Usage:

Make sure the appropriate changes to the schema are made!

For jsonb backend:
```
module DataCycleCore
  class ClassificationAlias < ApplicationRecord
    extend ::Translations
    translates :name, :description, column_suffix: '_i18n', backend: :jsonb
    default_scope { i18n }
  end
end
```
Here `:name` and `:description` are stored in columns `:name_i18n` and `:description_i18n`, respectively.
The fromat is
```
{
  'de' => 'Nicht freigegeben',
  'en' => 'not released'
}
```
With default scoping you have now methods of name and description that take the actual locale set in I18n.locale into account:
```
I18n.locale = :de
classification = DataCycleCore::ClassificationAlias.new
classification.name = 'Benutzer'
classification.description = 'Benutzer1'
classification.name
#=> 'Benutzer'
classification.description
#=> 'Benutzer1'
classification.save
classification = DataCycleCore::ClassificationAlias.first
classification.name
#=> 'Benutzer'
classification.description
#=> 'Benutzer1'
I18n.locale = :en
classification.name = 'User'
classification.name
#=> 'User'
I18.with_locale(:de) { classification.name }
#=> 'Benutzer'
classification.name_i18n
#=> { 'de' => 'Benutzer', 'en' => 'User' }
```

### Testing:
basic tests:
```
> bundle exec rspec
```

full tests:
```
> ORM=active_record DB=postgres bundle exec rspec
```
