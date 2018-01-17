module DataCycleCore
  class DataLinksController < ApplicationController
    before_action :authenticate_user!, only: [:new] # from devise (authenticate)
    load_and_authorize_resource :except => [:show] # from cancancan (authorize)

    def show
      link = DataCycleCore::DataLink.find_by(id: params[:id])

      unless !link.nil? && link.is_valid?
        raise ActiveRecord::RecordNotFound.new('Link nicht mehr gültig!')
      end

      session[:can_edit_ids] ||= []
      session[:can_edit_ids] << link.id unless session[:can_edit_ids].include?(link.id)

      sign_in(link.receiver)
      link.update_attribute(:seen_at, DateTime.now)

      if link.permissions != "write"
        redirect_to polymorphic_path(link.item)
      else
        redirect_to edit_polymorphic_path(link.item, split_params)
      end
    end

    def create
      unless receiver_params[:email] =~ Devise.email_regexp
        redirect_back(fallback_location: root_path, alert: (I18n.t :invalid_mail, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
      end

      unless DataCycleCore::DataLink.joins(:receiver).where(item_type: create_link_params[:item_type], item_id: create_link_params[:item_id], users: { email: receiver_params[:email] }).empty?
        redirect_back(fallback_location: root_path, alert: (I18n.t :email_exists, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return
      end

      @data_link = DataCycleCore::DataLink.new(create_link_params)
      @data_link.creator = current_user unless current_user.nil?

      @receiver = DataCycleCore::User.where(email: receiver_params[:email]).first_or_create(receiver_params.merge(password: SecureRandom.hex, role: DataCycleCore::Role.find_by(rank: 0)))
      @data_link.receiver = @receiver
      @data_link.save

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later

      redirect_back(fallback_location: root_path, notice: (I18n.t :saved_and_sent, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    def update
      @data_link = DataCycleCore::DataLink.find(params[:id])

      @data_link.update_attributes(create_link_params.merge(creator_id: current_user.id))

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later

      redirect_back(fallback_location: root_path, notice: (I18n.t :updated_and_sent, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    def destroy
      @data_link = DataCycleCore::DataLink.find(params[:id])
      @data_link.update_attribute(:valid_until, DateTime.now)

      redirect_back(fallback_location: root_path, notice: (I18n.t :invalidated, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    private

    def create_link_params
      params[:data_link][:valid_until] = params.dig(:data_link, :valid_until)&.to_datetime&.end_of_day.to_s
      params.require(:data_link).permit(:item_id, :item_type, :permissions, :comment, :valid_from, :valid_until)
    end

    def receiver_params
      params.require(:data_link).require(:receiver).permit(:email, :given_name, :family_name)
    end

    def split_params
      params.permit(:source_type, :source_id)
    end

    def url_split_params
      params.require(:data_link).permit(:source_type, :source_id)
    end
  end
end
