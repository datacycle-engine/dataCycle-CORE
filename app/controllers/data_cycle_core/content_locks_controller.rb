# frozen_string_literal: true

module DataCycleCore
  class ContentLocksController < ApplicationController
    include DataCycleCore::ErrorHandler
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    before_action :authenticate_user!

    def update
      @content_lock = DataCycleCore::ContentLock.find(params[:id])

      return(head :ok) unless @content_lock.user == current_user

      @content_lock&.touch
      head :ok
    end

    def destroy
      @content_lock = DataCycleCore::ContentLock.find(params[:id])

      return(head :ok) unless @content_lock.user == current_user

      @content_lock.destroy
      head :ok
    end
  end
end
