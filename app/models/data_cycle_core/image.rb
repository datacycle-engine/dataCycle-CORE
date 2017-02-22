class Image < ActiveRecord::Base
  
  include DataSetter

  belongs_to :external_sources

  has_many :images_place
  has_many :places, through: :images_place

end
