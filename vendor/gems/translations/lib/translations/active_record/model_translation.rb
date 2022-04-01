# frozen_string_literal: true

module Translations
  module ActiveRecord
    class ModelTranslation < ::ActiveRecord::Base
      self.abstract_class = true
      validates :locale, presence: true
    end
  end
end
