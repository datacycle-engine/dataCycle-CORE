# frozen_string_literal: true

require 'data_cycle_core/css_inliner'

ActionMailer::Base.register_interceptor(DataCycleCore::CssInliner)
