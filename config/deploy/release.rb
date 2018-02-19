# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# activate for deployment:
server '37.61.206.122', user: 'pixelpoint', roles: ['app', 'db', 'web']
set :branch, 'release'
set :rails_env, 'release'
set :deploy_to, '/var/www/data-cycle-core/release'
set :cmd_prefix, 'app:'
set :application_root_path, 'test/dummy/'
