# frozen_string_literal: true

DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', Rails.env, '*', '**', '*.yml'))
DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', Rails.env, '*.yml'))
DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', '*', '**', '*.yml'), false)
DataCycleCore.load_configurations(Rails.root.join('config', 'configurations', '*.yml'))

DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', Rails.env, '*', '**', '*.yml'))
DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', Rails.env, '*.yml'))
DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', '*', '**', '*.yml'), false)
DataCycleCore.load_configurations(DataCycleCore::Engine.root.join('config', 'configurations', '*.yml'))
