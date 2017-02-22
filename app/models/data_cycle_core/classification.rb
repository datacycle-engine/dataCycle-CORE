class Classification < ActiveRecord::Base

  include DataSetter

  belongs_to :external_sources

  has_many :classifications_places
  has_many :places, through: :classifications_places

  has_many :classifications_groups
  has_many :classifications_aliases, through: :classifications_groups
end
