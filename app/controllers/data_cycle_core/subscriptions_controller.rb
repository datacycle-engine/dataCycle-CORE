# frozen_string_literal: true

module DataCycleCore
  class SubscriptionsController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)

    def index
      authorize! :index, DataCycleCore::Subscription
      @contents = current_user.things_subscribed.includes(
        :translations,
        :watch_lists,
        :external_source,
        :external_systems,
        :parent,
        :primary_classification_aliases,
        classification_aliases: [:classification_alias_path, :classification_tree_label]
      ).order(updated_at: :desc).page(params[:page])
      @total = @contents.size
      @mode = mode_params[:mode] || 'grid'

      respond_to do |format|
        format.html
        format.js { render 'data_cycle_core/application/more_results' }
      end
    end

    def create
      authorize! :subscribe, DataCycleCore::Thing
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

      authorize! :subscribe, DataCycleCore::Thing
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

    def mode_params
      params.permit(:mode)
    end
  end
end
