# frozen_string_literal: true

namespace :dc do
  desc 'Autotranslate all contents in stored_filter or watch_list'
  task :auto_translate, [:endpoint_id_or_slug] => :environment do |_, args|
    abort('feature disabled!') unless DataCycleCore::Feature::AutoTranslation.enabled?
    abort('endpoint missing!') if args.endpoint_id_or_slug.blank?

    stored_filter = DataCycleCore::StoredFilter.by_id_or_slug(args.endpoint_id_or_slug).first
    watch_list = DataCycleCore::WatchList.without_my_selection.by_id_or_slug(args.endpoint_id_or_slug).first if stored_filter.nil?

    abort('endpoint not found!') if stored_filter.nil? && watch_list.nil?

    contents = stored_filter.nil? ? watch_list.things : stored_filter.apply.query
    progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'AutoTranslate')
    source_locale = DataCycleCore::Feature::AutoTranslation.configuration['source_lang'] || I18n.locale

    contents.find_each do |content|
      DataCycleCore::AutoTranslationJob.perform_later(content.id, source_locale)
      progressbar.increment
    end
  end
end
