# frozen_string_literal: true

module DataCycleCore
  class SubscriptionsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def index
      authorize! :index, DataCycleCore::Subscription
      @contents = current_user.subscriptions.includes(:subscribable).order(updated_at: :desc).page(params[:page])
    end

    def create
      object_type = data_cycle_object(subscription_params['subscribable_type'].demodulize.tableize)
      authorize! :subscribe, object_type
      @subscription = current_user.subscriptions.build(subscription_params)

      respond_to do |format|
        if !@subscription.nil? && @subscription.save
          format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: 'Abonnement', locale: DataCycleCore.ui_language)) }
          format.js
        else
          format.html { redirect_back(fallback_location: root_path) }
        end
      end
    end

    def destroy
      @subscription = DataCycleCore::Subscription.find(params[:id])
      object_type = data_cycle_object(@subscription.subscribable_type.demodulize.tableize)

      authorize! :subscribe, object_type
      @subscription.destroy

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :destroyed, scope: [:controllers, :success], data: 'Abonnement', locale: DataCycleCore.ui_language)) }
        format.js
      end
    end

    private

    def subscription_params
      params.permit(:subscribable_id, :subscribable_type)
    end
  end
end
