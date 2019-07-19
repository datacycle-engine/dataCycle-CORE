# frozen_string_literal: true

module DataCycleCore
  class SchemaController < ApplicationController
    def index
      respond_to do |format|
        format.xlsx
        format.any
      end
    end

    def show
      @schema = Thing.where(template: true).where("schema -> 'api' ->> 'type' = ?", params[:id]).first&.schema

      @schema = Thing.where(template: true, template_name: params[:id]).first&.schema if @schema.nil?

      raise ActiveRecord::RecordNotFound if @schema.nil?

      redirect_to schema_path(id: @schema.dig('api', 'type')) if @schema.dig('api', 'type') && @schema.dig('api', 'type') != params[:id]
    end
  end
end
