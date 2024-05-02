# frozen_string_literal: true

module DataCycleCore
  class ContentProperties < ApplicationRecord
    belongs_to :thing_template, inverse_of: false, foreign_key: :template_name, primary_key: :template_name
  end
end
