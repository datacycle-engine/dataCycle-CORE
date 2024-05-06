# frozen_string_literal: true

module DataCycleCore
  class DataLinksController < ApplicationController
    load_and_authorize_resource except: [:show, :get_text_file, :download, :render_update_form, :unlock] # from cancancan (authorize)
    after_action :update_receiver_locale, only: [:create, :update]

    def show
      @data_link = DataCycleCore::DataLink.find_by(id: params[:id])

      raise CanCan::AccessDenied unless @data_link.try(:is_valid?)

      sign_in(@data_link.receiver, store: !@data_link.downloadable?) if !signed_in? && @data_link.receiver&.can?(:auto_login, @data_link)
      @data_link.update_column(:seen_at, Time.zone.now)

      if @data_link.writable? && @data_link.item.is_a?(DataCycleCore::Thing)
        redirect_to edit_polymorphic_path(@data_link.item, split_params)
      elsif @data_link.downloadable? && DataCycleCore::Feature::Download.confirmation_required?
        render 'download', layout: 'layouts/data_cycle_core/devise'
      elsif @data_link.downloadable?
        redirect_to download_data_link_path(@data_link)
      else
        redirect_to polymorphic_path(@data_link.item)
      end
    end

    def create
      redirect_back(fallback_location: root_path, alert: (I18n.t :invalid_mail, scope: [:controllers, :success], locale: helpers.active_ui_locale)) && return unless receiver_params[:id].present? || receiver_params[:email].match?(Devise.email_regexp)

      if receiver_params[:id].present?
        @receiver = DataCycleCore::User.find_by(id: receiver_params[:id])
      else
        @receiver = DataCycleCore::User.where(email: receiver_params[:email]).first_or_initialize(receiver_params.merge(password: SecureRandom.hex, role: DataCycleCore::Role.find_by(rank: 0)))
      end

      redirect_back(fallback_location: root_path, alert: (I18n.t :invalid_mail, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return unless @receiver.valid?

      redirect_back(fallback_location: root_path, alert: (I18n.t :user_locked, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return if @receiver.locked?

      redirect_back(fallback_location: root_path, alert: (I18n.t :email_exists, scope: [:controllers, :error], locale: helpers.active_ui_locale)) && return if DataCycleCore::DataLink.joins(:receiver).exists?(item_type: data_link_params[:item_type], item_id: data_link_params[:item_id], users: { email: @receiver.email })

      @data_link = DataCycleCore::DataLink.new(data_link_params)
      @data_link.creator = current_user

      @receiver.save! if @receiver.new_record?
      @data_link.receiver = @receiver
      @data_link.save!

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later if send_email_params[:send] == '1'

      redirect_back(fallback_location: root_path, notice: (I18n.t "saved#{send_email_params[:send] == '1' ? '_and_sent' : ''}", data: DataCycleCore::DataLink.model_name.human(count: 1, locale: helpers.active_ui_locale), scope: [:controllers, :success], locale: helpers.active_ui_locale))
    end

    def update
      @data_link = DataCycleCore::DataLink.find(params[:id])

      params[:data_link][:asset_id] = nil if data_link_params[:asset_id].blank?

      @data_link.update(data_link_params)

      DataLinkMailer.mail_link(@data_link, data_link_url(@data_link, url_split_params)).deliver_later if send_email_params[:send] == '1'

      redirect_back(fallback_location: root_path, notice: (I18n.t "updated#{send_email_params[:send] == '1' ? '_and_sent' : ''}", scope: [:controllers, :success], data: DataCycleCore::DataLink.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def destroy
      @data_link = DataCycleCore::DataLink.find(params[:id])
      @data_link.update_column(:valid_until, 1.minute.ago)

      redirect_back(fallback_location: root_path, notice: (I18n.t :invalidated, scope: [:controllers, :success], data: DataCycleCore::DataLink.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def unlock
      @data_link = DataCycleCore::DataLink.find(params[:id])

      authorize! :update, @data_link

      @data_link.update_column(:valid_until, nil)

      redirect_back(fallback_location: root_path, notice: (I18n.t :unlocked, scope: [:controllers, :success], data: DataCycleCore::DataLink.model_name.human(count: 1, locale: helpers.active_ui_locale), locale: helpers.active_ui_locale))
    end

    def get_text_file
      @data_link = DataCycleCore::DataLink.find(params[:id])

      raise ActiveRecord::RecordNotFound if @data_link.text_file.blank?

      file_name = (@data_link.text_file.name.presence || DataCycleCore::DataLink.human_attribute_name('text_file', locale: helpers.active_ui_locale)).underscore_blanks
      extension = MiniMime.lookup_by_content_type(@data_link.text_file.content_type)&.extension || @data_link.text_file.content_type.split('/').last

      path_to_file = @data_link.text_file.file.service.path_for(@data_link.text_file.file.key)

      send_file path_to_file,
                type: @data_link.text_file.content_type,
                disposition: :inline,
                filename: "#{file_name}.#{extension}"
    end

    def render_update_form
      @receiver = receiver_params[:id].present? ? DataCycleCore::User.find(receiver_params[:id]) : DataCycleCore::User.new

      authorize! :create, DataCycleCore::DataLink

      render json: {
        html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/data_links/receiver_form', locals: { receiver: @receiver, namespace: render_update_form_params[:namespace] })
      }
    end

    private

    def update_receiver_locale
      return unless @data_link&.locale.present? && @data_link&.receiver&.is_role?('guest')

      @data_link.receiver.update_columns(ui_locale: @data_link.locale)
    end

    def data_link_params
      params
        .require(:data_link)
        .permit(:id, :item_id, :item_type, :creator_id, :permissions, :comment, :valid_from, :valid_until, :asset_id, :locale)
        .tap do |p|
          p[:valid_until] = p[:valid_until]&.to_datetime&.end_of_day.to_s
        end
    end

    def render_update_form_params
      params.permit(:namespace)
    end

    def receiver_params
      params
        .require(:data_link)
        .require(:receiver)
        .permit(:id, :email, :given_name, :family_name, :name, :confirmed_at)
        .tap do |p|
          p[:email] ||= p.delete(:id) unless p[:id].to_s.uuid?
          p[:email]&.downcase!
        end
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
