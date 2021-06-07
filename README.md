# DataCycleCore

DataCycleCore provides the main funcionality for the DataCycle project. It includes
the description for the core PostgreSQL database with all data- and table-definitions.

## Setup

To setup a new DataCycle project, follow the instructions from the base project:
http://git.pixelpoint.biz/data-cycle/data-cycle-base

## Dummy App

### Requirements

See base project.

#### Docker

```bash
$ alias dc='docker-compose'
```

```bash
$ dc build
$ dc stop && dc up -d && docker attach datacycle[LOCAL_DIR]_web_1
$ dc exec web bash
```

### Initial rake tasks

```bash
$ rake app:db:create
$ rake app:db:migrate
$ rake app:db:seed
$ rake app:data_cycle_core:update:import_classifications
$ rake app:data_cycle_core:update:import_templates
```

#### assets

```bash
yarn && yarn upgrade
```

## Testing

```bash
$ bundle-audit update
$ bundle audit check
$ brakeman
$ gemsurance
$ rubocop --format fuubar#
$ RAILS_ENV=test bundle exec rake app:db:drop app:db:create app:db:structure:load app:db:migrate app:db:seed && bundle exec rails test
```

## License

Copyright 2017-2020 Pixelpoint.at
