# frozen_string_literal: true

configured_environments = ActiveRecord::Base.configurations.to_h.keys.without('default')

DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', Rails.env, '*', '**', '*.yml'))
DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', Rails.env, '*.yml'))
DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', '*', '**', '*.yml'), configured_environments)
DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', '*.yml'))

DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', Rails.env, '*', '**', '*.yml'))
DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', Rails.env, '*.yml'))
DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', '*', '**', '*.yml'), configured_environments)
DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', '*.yml'))
