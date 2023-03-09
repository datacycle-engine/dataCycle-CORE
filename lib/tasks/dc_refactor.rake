# frozen_string_literal: true

namespace :dc do
  namespace :refactor do
    desc 'add dummy element to overlay'
    task :add_dummy, [:overlay_name] => [:environment] do |_, args|
      overlay_name = args.overlay_name
      abort('ERROR: template does not exist, or is not of type embedded') if DataCycleCore::Thing.find_by(template: true, template_name: overlay_name)&.embedded?
      overlays = DataCycleCore::Thing.where(template: false, template_name: overlay_name)
      overlays.each do |i|
        i.content = i.content.nil? ? { dummy: 'do_not_show' } : i.content.merge({ dummy: 'do_not_show' })
        i.save
      end
    end
  end
end
