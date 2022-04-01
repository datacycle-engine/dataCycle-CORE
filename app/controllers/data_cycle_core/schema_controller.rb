# frozen_string_literal: true

module DataCycleCore
  class SchemaController < ApplicationController
    def index
      @schema = Schema.load_schema_from_database

      respond_to do |format|
        format.xlsx
        format.any
      end
    end

    def show
      @schema = Schema.load_schema_from_database

      @template_schema = @schema.template_by_template_name(params[:id])
      @template_schema = @schema.template_by_schema_name(params[:id]) if @template_schema.nil?

      raise ActiveRecord::RecordNotFound, "Couldn't find template '#{params[:id]}'" if @template_schema.nil?
    end
  end
end
