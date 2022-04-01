# frozen_string_literal: true

class ChangePersonHistoriesForRubyNameConventions < ActiveRecord::Migration[5.0]
  def change
    rename_column :person_histories, :givenName, :given_name
    rename_column :person_histories, :familyName, :family_name
  end
end
