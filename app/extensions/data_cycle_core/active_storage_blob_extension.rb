# frozen_string_literal: true

##############################################################################################################
######################### TAKEN FROM RAILS main branch to allow byte streaming ###############################
######### https://github.com/rails/rails/blob/main/activestorage/app/models/active_storage/blob.rb ###########
######################### [TODO] delete after upgrade to Rails 7.0.0 #########################################
##############################################################################################################

module DataCycleCore
  module ActiveStorageBlobExtension
    def download_chunk(range)
      service.download_chunk key, range
    end
  end
end
