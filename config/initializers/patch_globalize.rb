# app/models/application_record.rb
# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Rails 5.1 requires each non database attribute to be specified.
  #
  # This means every attribute which is translated by Globalize needs to be
  # declared with class method `attribute`.
  #
  # This could be removed if Globalize fully supports Rails 5.1
  class << self
    def translates(*attr_names)
      attr_names.each { |attr_name| attribute attr_name }

      super
    end
  end
end