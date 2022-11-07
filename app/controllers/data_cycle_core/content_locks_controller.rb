# frozen_string_literal: true

module DataCycleCore
  class ContentLocksController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :decode_token # from devise (authenticate)

    def update
      return(head :no_content) if @decoded[:lock_ids].blank?

      @content_locks = DataCycleCore::ContentLock.where(id: @decoded[:lock_ids])

      return(head :no_content) unless @content_locks.includes(:user).all? { |l| l.user == current_user }

      @content_locks.find_each(&:touch)

      head :no_content
    end

    def destroy
      return(head :no_content) if @decoded[:lock_ids].blank?

      @content_locks = DataCycleCore::ContentLock.where(id: @decoded[:lock_ids])

      return(head :no_content) unless @content_locks.includes(:user).all? { |l| l.user == current_user }

      @content_locks.find_each(&:destroy)

      head :no_content
    end

    private

    def hopefully_not_triggered
      raise 'Content Lock destroy/update failed - Browser Windows closed'
    end

    def decode_token
      @decoded = DataCycleCore::JsonWebToken.decode(params[:token]) || {}
    rescue JWT::DecodeError, JSON::ParserError
      @decoded = {}
    end
  end
end
