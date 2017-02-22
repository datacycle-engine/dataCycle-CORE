class ImagesPlace < ActiveRecord::Base

  include DataSetter

  belongs_to :external_sources

  belongs_to :place
  belongs_to :image

end
