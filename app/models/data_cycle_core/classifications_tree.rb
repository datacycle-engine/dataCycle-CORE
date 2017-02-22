class ClassificationsTree < ActiveRecord::Base

  include DataSetter

  belongs_to :external_sources

  belongs_to :sub_classifications_alias, class_name: 'ClassificationsAlias', foreign_key: 'classifications_alias_id'
  belongs_to :parent_classifications_alias, class_name: 'ClassificationsAlias', foreign_key: 'parent_classifications_alias_id'

end
