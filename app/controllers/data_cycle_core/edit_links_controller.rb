module DataCycleCore
  class EditLinksController < ApplicationController
    before_action :authenticate_user!, only: [:new]   # from devise (authenticate)
    # load_and_authorize_resource         # from cancancan (authorize)

    def show
      link = DataCycleCore::EditLink.find_by(id: params[:id])
      @item = link.item_type.constantize.find_by(id: link.item_id)

      session[:can_edit_ids] ||= []
      session[:can_edit_ids] << link.id unless session[:can_edit_ids].include?(link.id)

      guest_user

      redirect_to polymorphic_path(@item)
    end

    def new
      @edit_link = DataCycleCore::EditLink.new(create_link_params)
      @edit_link.creator = current_user unless current_user.nil?

      @edit_link.save

      # EditLinkMailer.mail_link(@edit_link.creator, url_for(@edit_link), "bearbeiten").deliver_later
      EditLinkMailer.mail_link(@edit_link.creator, url_for(@edit_link), "bearbeiten").deliver

      flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Edit Link'
      redirect_back(fallback_location: root_path)
    end

    def destroy
      link = DataCycleCore::EditLink.find_by(id: params[:id]).destroy
      redirect_back fallback_location: root_path, alert: (I18n.t :destroyed, scope: [:controllers, :success], data: 'Edit Link')
    end

    private

    def create_link_params
      params.permit(:item_id, :item_type)
    end

    def guest_user
      @guest_user ||= DataCycleCore::User.find(session[:guest_user_id] ||= find_or_create_guest_user.id)

    rescue ActiveRecord::RecordNotFound
      session[:guest_user_id] = nil
      guest_user
    end

    def find_or_create_guest_user
      if DataCycleCore::User.where(role: "guest").count > 0
        u = DataCycleCore::User.where(role: "guest").first
      else
        u = DataCycleCore::User.create(email: "guest@datacycle.at", name: "Guest", role: "guest")
        u.save!(validate: false)
      end

      session[:guest_user_id] = u.id

      u
    end

  end
end
