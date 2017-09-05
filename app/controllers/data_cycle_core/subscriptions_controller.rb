module DataCycleCore
  class SubscriptionsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)

    def create
      @subscription = current_user.subscriptions.build(subscription_params)

      respond_to do |format|
        if !@subscription.nil? && @subscription.save
          format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: 'Abonnement')) }
          format.js
        else
          format.html { redirect_back(fallback_location: root_path) }
        end
      end
    end

    def destroy
      @subscription = DataCycleCore::Subscription.find(params[:id])
      @subscription.destroy

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :destroyed, scope: [:controllers, :success], data: 'Abonnement')) }
        format.js
      end
    end

    private

      def subscription_params
        params.permit(:subscribable_id, :subscribable_type)
      end

  end
end
