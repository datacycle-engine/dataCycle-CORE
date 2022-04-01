# frozen_string_literal: true

namespace :dc do
  namespace :refactor do
    namespace :classifications do
      desc 'move classification from one path to another z.B Inhaltstypen|Bild,Inhaltstypen|Assets|Bild'
      task :move_from_to, [:from_path, :to_path, :destroy_children, :prevent_webhooks] => [:environment] do |_, args|
        from_path = args.from_path&.split('|')&.map { |s| s.delete('"') }
        to_path = args.to_path&.split('|')&.map { |s| s.delete('"') }

        destroy_children = args.destroy_children&.to_s == 'true'

        abort('ERROR: Missing from- or to_path') if from_path.blank? || to_path.blank?

        from_ca = DataCycleCore::ClassificationAlias.includes(:classification_alias_path).find_by(classification_alias_paths: { full_path_names: from_path.reverse })

        abort('ERROR: from ClassificationAlias not found') if from_ca.nil?

        from_ca.prevent_webhooks = args.prevent_webhooks&.to_s == 'true'

        new_ca = from_ca.move_to_path(to_path, destroy_children)

        abort('ERROR: error moving to new path') unless new_ca.is_a?(DataCycleCore::ClassificationAlias)

        puts('WARNING: classifications moved to another tree! Check if relation in DataCycleCore::ClassificationContent needs to be updated!') if from_path.first != to_path.first

        puts("SUCCESS: successfully moved classification to new path: #{new_ca.reload.full_path}")
      end
    end

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
