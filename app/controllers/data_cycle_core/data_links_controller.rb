# frozen_string_literal: true

module DataCycleCore
  class DataLinksController < ApplicationController
    before_action :authenticate_user!, except: [:show, :find, :get_text_file] # from devise (authenticate)
    load_and_authorize_resource except: [:show, :find, :get_text_file] # from cancancan (authorize)

    def show
      link = DataCycleCore::DataLink.find_by(id: params[:id])

      raise CanCan::AccessDenied unless link.try(:is_valid?)

      session[:can_edit_ids] ||= []
      session[:can_edit_ids] << link.id unless session[:can_edit_ids].include?(link.id)

      sign_in(link.receiver) if link.creator.role.rank > link.receiver.role.rank

      link.update_attribute(:seen_at, Time.zone.now)

      if link.permissions == 'write' && DataCycleCore.content_tables.include?(link.item.class.table_name)
        redirect_to edit_polymorphic_path(link.item, split_params)
      else
        redirect_to polymorphic_path(link.item)
      end
    end

    def create
      redirect_back(fallback_location: root_path, alert: (I18n.t :invalid_mail, scope: [:controllers, :success], locale: DataCycleCore.ui_language)) && return unless receiver_params[:email].match?(Devise.email_regexp)

      redirect_back(fallback_location: root_path, alert: (I18n.t :email_exists, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return unless DataCycleCore::DataLink.joins(:receiver).where(item_type: create_link_params[:item_type], item_id: create_link_params[:item_id], users: { email: receiver_params[:email] }).empty?

      @data_link = DataCycleCore::DataLink.new(create_link_params)
      @data_link.creator = current_user if current_user.present?

      @receiver = DataCycleCore::User.where(email: receiver_params[:email]).first_or_create(receiver_params.merge(password: SecureRandom.hex, role: DataCycleCore::Role.find_by(rank: 0)))
      @data_link.receiver = @receiver
      @data_link.save

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later

      redirect_back(fallback_location: root_path, notice: (I18n.t :saved_and_sent, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    def update
      @data_link = DataCycleCore::DataLink.find(params[:id])

      params[:data_link][:asset_id] = nil if create_link_params[:asset_id].blank?

      @data_link.update(create_link_params)

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later

      redirect_back(fallback_location: root_path, notice: (I18n.t :updated_and_sent, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    def destroy
      @data_link = DataCycleCore::DataLink.find(params[:id])
      @data_link.update_attribute(:valid_until, Time.zone.now)

      redirect_back(fallback_location: root_path, notice: (I18n.t :invalidated, scope: [:controllers, :success], locale: DataCycleCore.ui_language))
    end

    def find
      authorize! :create, DataCycleCore::DataLink

      @duplicate = DataCycleCore::TextFile.find_by('name ILIKE ?', params[:q])

      render json: @duplicate&.attributes&.merge(editable: can?(:edit, @duplicate))
    end

    def get_text_file
      @data_link = DataCycleCore::DataLink.find(params[:id])

      raise ActiveRecord::RecordNotFound if @data_link.text_file.blank?

      send_file(@data_link.text_file.file.current_path, type: @data_link.text_file.content_type, disposition: :inline, filename: "#{@data_link.text_file.name.presence&.parameterize(separator: '_') || DataCycleCore::DataLink.human_attribute_name('text_file', locale: DataCycleCore.ui_language).parameterize(separator: '_')}.#{@data_link.text_file.content_type.split('/').last}")
    end

    private

    def create_link_params
      params[:data_link][:valid_until] = params.dig(:data_link, :valid_until)&.to_datetime&.end_of_day.to_s
      params.require(:data_link).permit(:item_id, :item_type, :creator_id, :permissions, :comment, :valid_from, :valid_until, :asset_id)
    end

    def receiver_params
      params.require(:data_link).require(:receiver).permit(:email, :given_name, :family_name)
    end

    def split_params
      params.permit(:source_table, :source_id)
    end

    def url_split_params
      params.require(:data_link).permit(:source_table, :source_id)
    end
  end
end
