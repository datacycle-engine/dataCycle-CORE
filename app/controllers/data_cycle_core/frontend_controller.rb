# frozen_string_literal: true

module DataCycleCore
  class FrontendController < ApplicationController
    def index
    end

    def info
      redirect_to authenticated_root_path
    end
  end
end
