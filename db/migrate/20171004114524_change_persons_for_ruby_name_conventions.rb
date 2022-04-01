# frozen_string_literal: true

class ChangePersonsForRubyNameConventions < ActiveRecord::Migration[5.0]
  def change
    rename_column :persons, :givenName, :given_name
    rename_column :persons, :familyName, :family_name
  end
end
