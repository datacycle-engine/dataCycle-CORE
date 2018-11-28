# frozen_string_literal: true

module DataCycleCore
  class SchemaController < ApplicationController
    def index
      respond_to do |format|
        format.xlsx
        format.any
      end
    end
  end
end
