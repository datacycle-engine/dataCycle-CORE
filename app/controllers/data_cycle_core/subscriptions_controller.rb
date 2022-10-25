# frozen_string_literal: true

module DataCycleCore
  class SubscriptionsController < ApplicationController
    include DataCycleCore::Filter

    def index
      authorize! :index, DataCycleCore::Subscription
      pre_filters
      @pre_filters.push(
        {
          't' => 'subscribed_user_id',
          'v' => current_user.id
        }
      )

      set_instance_variables_by_view_mode(query: @query, user_filter: { scope: 'subscriptions' })

      respond_to do |format|
        format.html
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').squish } }
      end
    end

    def create
      authorize! :subscribe, DataCycleCore::Thing
      @subscription = current_user.subscriptions.build(subscription_params)

      respond_to do |format|
        if !@subscription.nil? && @subscription.save
          format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :created, scope: [:controllers, :success], data: 'Abonnement', locale: helpers.active_ui_locale)) }
          format.js
        else
          format.html { redirect_back(fallback_location: root_path) }
        end
      end
    end

    def destroy
      @subscription = DataCycleCore::Subscription.find(params[:id])

      authorize! :subscribe, DataCycleCore::Thing
      @subscription.destroy

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: (I18n.t :destroyed, scope: [:controllers, :success], data: 'Abonnement', locale: helpers.active_ui_locale)) }
        format.js
      end
    end

    private

    def subscription_params
      params.permit(:subscribable_id, :subscribable_type)
    end
  end
end
