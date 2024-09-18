# frozen_string_literal: true

###################################################################################################################
############################## TAKEN FROM RAILS main branch to allow byte streaming ###############################
### https://github.com/rails/rails/blob/main/activestorage/app/controllers/concerns/active_storage/streaming.rb ###
############################## [TODO] delete after upgrade to Rails 7.0.0 #########################################
###################################################################################################################

module DataCycleCore
  module ActiveStorageProxyControllerExtension
    extend ActiveSupport::Concern

    include DataCycleCore::ActiveStorageStreaming

    def show
      if request.headers['Range'].present?
        send_blob_byte_range_data @blob, request.headers['Range']
      else
        super
      end
    end
  end
end
