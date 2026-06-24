# frozen_string_literal: true

require 'data_cycle_core/css_inliner'
require 'data_cycle_core/filter_noreply'

ActionMailer::Base.register_interceptor(DataCycleCore::CssInliner)
ActionMailer::Base.register_interceptor(DataCycleCore::FilterNoreply)
