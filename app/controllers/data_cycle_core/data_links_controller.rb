module DataCycleCore
  class DataLinksController < ApplicationController
    before_action :authenticate_user!, only: [:new]   # from devise (authenticate)
    load_and_authorize_resource :except => [:show]         # from cancancan (authorize)

    def show
      link = DataCycleCore::DataLink.find_by(id: params[:id])
      @item = link.item_type.constantize.find_by(id: link.item_id)

      session[:can_edit_ids] ||= []
      session[:can_edit_ids] << link.id unless session[:can_edit_ids].include?(link.id)

      guest_user

      if link.permissions != "write"
        redirect_to polymorphic_path(@item)
      else
        redirect_to edit_polymorphic_path(@item, split_params)
      end

    end

    def create
      raise "test"
      if DataCycleCore::DataLink.joins(:receiver).where(item_type: create_link_params[:item_type], item_id: create_link_params[:item_id], receiver: { email: receiver_params[:email]}).size > 0
        redirect_back(fallback_location: root_path, alert: (I18n.t :email_exists, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) and return
      end
      @data_link = DataCycleCore::DataLink.new(create_link_params)
      @data_link.creator = current_user unless current_user.nil?

      @receiver = DataCycleCore::User.where(email: receiver_params[:email]).first_or_create(receiver_params.merge(password: SecureRandom.hex, role_id: DataCycleCore::Role.find_by(rank: 0)))

      @data_link.receiver = @receiver
      @data_link.save

      redirect_back(fallback_location: root_path, notice: (I18n.t :saved_and_sent, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    def update
      @data_link = DataCycleCore::DataLink.find(params[:id])

      validity_period = [
        '[',
        validity_period_params[:valid_from].to_datetime.kind_of?(DateTime) ? validity_period_params[:valid_from].to_datetime.to_s(:long_usec) : DateTime.now.to_s(:long_usec),
        ',',
        validity_period_params[:valid_until].to_datetime.kind_of?(DateTime) ? validity_period_params[:valid_until].to_datetime.to_s(:long_usec) : '',
        ']'
      ].join('')

      @data_link.update_attributes(create_link_params.merge(creator: current_user, validity_period: validity_period))

      redirect_back(fallback_location: root_path, notice: (I18n.t :updated_and_sent, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    def send_mail
      @data_link = DataCycleCore::DataLink.find_by(id: params[:id])
      receiver = send_link_params[:receiver]

      if receiver =~ Devise.email_regexp
        DataLinkMailer.mail_link(@data_link.creator, receiver, data_link_url(@data_link, send_link_params[:url_params]), params[:type], send_link_params[:comment]).deliver_later
        redirect_back(fallback_location: root_path, notice: (I18n.t :sent, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
      else
        redirect_back(fallback_location: root_path, alert: (I18n.t :invalid_mail, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
      end

    end

    private

    def create_link_params
      params.require(:data_link).permit(:item_id, :item_type, :permissions, :comment, :valid_from, :valid_until)
    end

    def receiver_params
      params.require(:data_link).require(:receiver).permit(:email, :given_name, :family_name)
    end

    def split_params
      params.permit(:source_type, :source_id)
    end

    def send_link_params
      params.require(:data_link).permit(:receiver, :comment, :type, url_params: [:source_type, :source_id])
    end

    def guest_user
      @guest_user ||= DataCycleCore::User.find(session[:guest_user_id] ||= find_or_create_guest_user.id)

    rescue ActiveRecord::RecordNotFound
      session[:guest_user_id] = nil
      guest_user
    end

    def find_or_create_guest_user
      guest = DataCycleCore::Role.find_by(rank: 0)
      if DataCycleCore::User.where(email: "noreply@datacycle.at").count > 0
        u = DataCycleCore::User.find_by(email: "noreply@datacycle.at")
        u.update_attribute(:role_id, guest.id)
      else
        u = DataCycleCore::User.create(email: "noreply@datacycle.at", given_name: 'Shared', family_name: 'Guest', role_id: guest.id, external: false)
        u.save!(validate: false)
      end

      session[:guest_user_id] = u.id

      u
    end

  end
end
