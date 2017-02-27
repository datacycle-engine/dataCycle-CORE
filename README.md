# DataCycleCore
DataCycleCore provides the main funcionality for the DataCycle project. It includes
the description for the core PostgreSQL database with all data- and table-definitions.


## Setup
To setup a new DataCycle project, download and include the DataCycleCore engine.

At the moment DataCycleCore is no packaged gem-file. Therefore is has to be installed separately on your local disc and included in your Gemfile.

```ruby
gem 'data_cycle_core', path: 'your_local_path to data_cycle_core'
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
This line will mount the engine at "/dcc" in the application. Making it accessible at http://localhost:3000/dcc when the application runs with rails server.

Replace "/dcc" with the route you desire.

note: as for now the DataCyleCore Engines comes with a basic dashboard at
"(root::Engine)/", and a database view/manipulation tool at "(root::Engine)/db/". For safety this is only available in development environment.

### Database Migrations:
Execute:
```bash
$ rails DataCyleCore:install:migrations
```

This will copy all migrations to your "/db/migrate/" folder. If a newer version of
the Engine with additional migrations is available, run the command again and only
the pending migrations are copied over.

### Database Seeding:
In order to use the default Rails seed-task add the following line of code to your
"/db/seeds.rb" file:

```ruby
  DataCycleCore::Engine.load_seed
```


## License
Copyright 2017 Pixelpoint.at
