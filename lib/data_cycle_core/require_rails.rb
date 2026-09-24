# frozen_string_literal: true

# The Rails frameworks this engine expects an application to load, kept here rather than in each
# application's config/application.rb so one file names them. Lives under lib/ because the gemspec
# ships {app,config,db,lib} only, and both host_test_helper and test/dummy/lib/require_rails need
# it to be there.
require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require 'action_mailbox/engine'
# require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'
require 'rails/test_unit/railtie'
