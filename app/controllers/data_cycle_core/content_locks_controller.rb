# frozen_string_literal: true

module DataCycleCore
  class ContentLocksController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate

    def update
      return(head :no_content) if @decoded[:lock_ids].blank?

      @content_locks = DataCycleCore::ContentLock.where(id: @decoded[:lock_ids])

      return(head :no_content) unless @content_locks.includes(:user).all? { |l| l.user == current_user }

      @content_locks.find_each(&:touch)

      head :ok
    end

    def destroy
      return(head :no_content) if @decoded[:lock_ids].blank?

      @content_locks = DataCycleCore::ContentLock.where(id: @decoded[:lock_ids])

      return(head :no_content) unless @content_locks.includes(:user).all? { |l| l.user == current_user }

      @content_locks.find_each(&:destroy)

      head :ok
    end

    private

    def hopefully_not_triggered
      raise 'Content Lock destroy/update failed - Browser Windows closed'
    end

    def authenticate
      raise CanCan::AccessDenied, 'invalid or missing authentication token' if params[:token].blank?

      @decoded = DataCycleCore::JsonWebToken.decode(params[:token])
      @user = DataCycleCore::User.find(@decoded[:user_id])

      request.env['devise.skip_trackable'] = true
      sign_in @user, store: false
    rescue JWT::DecodeError, JSON::ParserError => e
      raise CanCan::AccessDenied, e.message
    end
  end
end
