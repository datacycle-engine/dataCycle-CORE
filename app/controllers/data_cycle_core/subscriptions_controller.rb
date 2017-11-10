module DataCycleCore
  class SubscriptionsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    layout 'data_cycle_core/list_contents'

    def index
      @subscriptions = current_user.subscriptions.includes(:subscribable).order(updated_at: :desc).page(params[:page])
    end

    def create
      authorize! :subscribe, subscription_params['subscribable_type'].constantize
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

      authorize! :subscribe, @subscription.subscribable_type.constantize
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
