# frozen_string_literal: true

module DataCycleCore
  class DataLinksController < ApplicationController
    include DataCycleCore::DownloadHandler if DataCycleCore::Feature::Download.enabled?

    before_action :authenticate_user!, except: [:show, :get_text_file] # from devise (authenticate)
    load_and_authorize_resource except: [:show, :get_text_file] # from cancancan (authorize)
    after_action :update_receiver_locale, only: [:create, :update]

    def show
      link = DataCycleCore::DataLink.find_by(id: params[:id])

      raise CanCan::AccessDenied unless link.try(:is_valid?)

      session[:can_edit_ids] ||= []
      session[:can_edit_ids] << link.id unless session[:can_edit_ids].include?(link.id)

      sign_in(link.receiver, store: !link.downloadable?) if link.creator.role.rank >= link.receiver.role.rank

      link.update_column(:seen_at, Time.zone.now)

      if link.writable? && link.item.is_a?(DataCycleCore::Thing)
        redirect_to edit_polymorphic_path(link.item, split_params)
      elsif link.downloadable? && link.item_type == 'DataCycleCore::Thing'
        download_content(link.item, 'asset', nil, nil)
      elsif link.downloadable? && link.item_type == 'DataCycleCore::WatchList'
        download_items = link.item.things.to_a.select do |thing|
          DataCycleCore::Feature::Download.allowed?(thing)
        end
        download_collection(link.item, download_items, ['asset'], nil, nil)
      else
        redirect_to polymorphic_path(link.item)
      end
    end

    def create
      redirect_back(fallback_location: root_path, alert: (I18n.t :invalid_mail, scope: [:controllers, :success], locale: helpers.active_ui_locale)) && return unless receiver_params[:email].match?(Devise.email_regexp) || receiver_params[:id].present?

      redirect_back(fallback_location: root_path, alert: (I18n.t :email_exists, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return unless DataCycleCore::DataLink.joins(:receiver).where(item_type: create_link_params[:item_type], item_id: create_link_params[:item_id], users: { email: receiver_params[:email] }).empty?

      @data_link = DataCycleCore::DataLink.new(create_link_params)
      @data_link.creator = current_user

      if receiver_params[:id].present?
        @receiver = DataCycleCore::User.find_by(id: receiver_params[:id])
      else
        @receiver = DataCycleCore::User.where(email: receiver_params[:email]).first_or_create!(receiver_params.merge(password: SecureRandom.hex, role: DataCycleCore::Role.find_by(rank: 0)))
      end

      redirect_back(fallback_location: root_path, alert: (I18n.t :invalid_mail, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return if @receiver.blank?

      @data_link.receiver = @receiver
      @data_link.save

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later if send_email_params[:send] == '1'

      redirect_back(fallback_location: root_path, notice: (I18n.t "saved#{send_email_params[:send] == '1' ? '_and_sent' : ''}", data: DataCycleCore::DataLink.model_name.human(count: 1, locale: helpers.active_ui_locale), scope: [:controllers, :success], locale: helpers.active_ui_locale))
    end

    def update
      @data_link = DataCycleCore::DataLink.find(params[:id])

      params[:data_link][:asset_id] = nil if create_link_params[:asset_id].blank?

      @data_link.update(create_link_params)

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later if send_email_params[:send] == '1'

      redirect_back(fallback_location: root_path, notice: (I18n.t "updated#{send_email_params[:send] == '1' ? '_and_sent' : ''}", scope: [:controllers, :success], data: DataCycleCore::DataLink.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def destroy
      @data_link = DataCycleCore::DataLink.find(params[:id])
      @data_link.update_column(:valid_until, 1.minute.ago)

      redirect_back(fallback_location: root_path, notice: (I18n.t :invalidated, scope: [:controllers, :success], data: DataCycleCore::DataLink.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def get_text_file
      @data_link = DataCycleCore::DataLink.find(params[:id])

      raise ActiveRecord::RecordNotFound if @data_link.text_file.blank?

      file_name = (@data_link.text_file.name.presence || DataCycleCore::DataLink.human_attribute_name('text_file', locale: helpers.active_ui_locale)).underscore_blanks
      extension = MiniMime.lookup_by_content_type(@data_link.text_file.content_type)&.extension || @data_link.text_file.content_type.split('/').last

      send_file @data_link.text_file.file.current_path,
                type: @data_link.text_file.content_type,
                disposition: :inline,
                filename: "#{file_name}.#{extension}"
    end

    private

    def update_receiver_locale
      return unless @data_link.locale.present? && @data_link.receiver.is_role?('guest')

      @data_link.receiver.update_columns(ui_locale: @data_link.locale)
    end

    def create_link_params
      params[:data_link][:valid_until] = params.dig(:data_link, :valid_until)&.to_datetime&.end_of_day.to_s
      params.require(:data_link).permit(:item_id, :item_type, :creator_id, :permissions, :comment, :valid_from, :valid_until, :asset_id, :locale)
    end

    def receiver_params
      params.dig(:data_link, :receiver, :email)&.downcase!
      params.require(:data_link).require(:receiver).permit(:id, :email, :given_name, :family_name, :confirmed_at)
    end

    def split_params
      params.permit(:source_table, :source_id)
    end

    def send_email_params
      params.permit(:send)
    end

    def url_split_params
      params.require(:data_link).permit(:source_table, :source_id)
    end
  end
end
