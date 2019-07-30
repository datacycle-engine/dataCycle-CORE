# frozen_string_literal: true

module DataCycleCore
  class ContentLocksController < ApplicationController
    include DataCycleCore::ErrorHandler
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActionController::InvalidAuthenticityToken, with: :hopefully_not_triggered

    before_action :authenticate_user!

    def update
      return(head :ok) if lock_params[:lock_ids].blank?

      @content_locks = DataCycleCore::ContentLock.where(id: lock_params[:lock_ids])

      return(head :ok) unless @content_locks.all? { |l| l.user == current_user }

      @content_locks.find_each(&:touch)

      head :ok
    end

    def destroy
      return(head :ok) if lock_params[:lock_ids].blank?

      @content_locks = DataCycleCore::ContentLock.where(id: lock_params[:lock_ids])

      return(head :ok) unless @content_locks.all? { |l| l.user == current_user }

      @content_locks.find_each(&:destroy)

      head :ok
    end

    private

    def hopefully_not_triggered
      raise 'Content Lock destroy/update failed - Browser Windows closed'
    end

    def lock_params
      params.permit(lock_ids: [])
    end
  end
end
