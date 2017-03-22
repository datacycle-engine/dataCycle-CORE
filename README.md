# DataCycleCore
DataCycleCore provides the main funcionality for the DataCycle project. It includes
the description for the core PostgreSQL database with all data- and table-definitions.


## Setup
To setup a new DataCycle project, download and include the DataCycleCore engine.

At the moment DataCycleCore is no packaged gem-file. Therefore it has to be installed separately on your local disc and included in your Gemfile.

```ruby
gem 'data_cycle_core', path: 'your_local_path to data_cycle_core'
```

Additionally you also have to include the globalize gem to your local Gemfile because it cannot be added as a dependecy to the gemspec file since the required version is only available via git.

```ruby
gem 'globalize', github: 'globalize/globalize'
```

Database config files for the PostgreSQL (/config/database.yml) and MongoDB
(/config/mongoid.yml)

## Usage
### Rooting:
mount the Engine to an endpoint of you liking.

```ruby
Rails.application.routes.draw do
  mount DataCycleCore::Engine => "/dcc"
end
```

Additionally you also have to include the globalize gem to your local Gemfile because it cannot be added as a dependecy to the gemspec file since the required version is only available via git.

```ruby
gem 'globalize', github: 'globalize/globalize'
```

This line will mount the engine at "/dcc" in the application. Making it accessible at http://localhost:3000/dcc when the application runs with rails server.

Replace "/dcc" with the route you desire.

### Database Migrations:
Execute as usual:
```bash
$ rails db:migrate
```

This will execute all local and engine migrations.

### Database Seeding:
In order to use the default Rails seed-task add the following line of code to your
"/db/seeds.rb" file:

```ruby
  DataCycleCore::Engine.load_seed
```


## License
Copyright 2017 Pixelpoint.at
