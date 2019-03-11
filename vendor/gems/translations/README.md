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

### For `:json` backend:
Configuration used for translatable DataCycleCore::ClassificationAlias:
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
Presence methods are also supported:
```
I18n.locale = :de
classification.name?
#=> true
classification.name = nil
classification.name?
#=> false
I18n.with_locale(:en) { classification.name? }
#=> true
```
Additional query integration:

specifying translated attributes as query parameters:
```
I18n.locale = :de
DataCycleCore::ClassificationAlias.where(name: 'Benutzer').count
#=> 1
```
Specifying query language:
```
DataCycleCore::ClassificationAlias.where(name: 'Benutzer', locale: :de).count
#=> 1
DataCycleCore::ClassificationAlias.where(name: 'Benutzer', locale: :en).count
#=> 0
DataCycleCore::ClassificationAlias.where(name: 'User', locale: :en).count
#=> 1
```
Additionally: integragtion with methods `pluck`, `order` (and basic support for `select` and `group`)

### For `:table` backend
Configuration used for DataCycleCore::Thing
```
module DataCycleCore
  class Thing < Content::DataHash
    extend ::Translations
    translates :name, :description, :content, backend: :table
    default_scope { i18n }  
  end
end
```
Here `:name`, `:description` and `:content` are stored in a separate table called `thing_translations`.
The translations table has to have the following columns:
- id
- thing_id (foreign_key to untranslated main table)
- locale (a column to store the language code)
- content columns (here: name, description and content)
- rails timestamps

For the `:table` backend the same accessor methods, as already shown for the `:jsonb` backend, are created.
```
I18n.locale = :de
thing = DataCycleCore::Thing.new
thing.name = 'Name'
thing.description = 'Beschreibung'
thing.save
thing.name
#=> 'Name'
thing.description
#=> 'Beschreibung'
I18n.locale = :en
thing.name = 'Title'
thing.description = 'description'
thing.save
```

Also the presence methods as well as the query integration are in place.
```
I18n.locale = :de
thing.name?
#=> true
DataCycleCore::Thing.where(name: 'Name').count
#=> 1
DataCycleCore::Thing.where(name: 'Name', locale: :de).count
#=> 1
DataCycleCore::Thing.where(name: 'Name', locale: :en).count
#=> 0
DataCycleCore::Thing.where(name: 'Title', locale: :en).count
#=> 1
```


## Testing:
basic tests:
```
> bundle exec rspec
```

full tests:
```
> ORM=active_record DB=postgres bundle exec rspec
```
