desc "start a jobs:work taks in the engine"
namespace :data_cycle_core do
  task :worker => :environment do
    puts Rake.application.instance_variable_get('@tasks').sort.each {|task| puts task}
    #Rake::Task['app:jobs:work'].invoke
  end
end
