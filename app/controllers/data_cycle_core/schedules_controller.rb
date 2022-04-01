# frozen_string_literal: true

module DataCycleCore
  class SchedulesController < ApplicationController
    before_action :authenticate_user!

    def load_more
      @schedule = load_more_params[:class_name].safe_constantize.find(load_more_params[:id])
      @direction = load_more_params[:direction]
      @occurrences = @schedule.try(:schedule_object).try("#{@direction}_occurrences", 5, load_more_params[:from_time])
      @target = load_more_params[:target]

      respond_to :js
    end

    private

    def load_more_params
      params.permit(:id, :direction, :from_time, :target, :class_name)
    end
  end
end
