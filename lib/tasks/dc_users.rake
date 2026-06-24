# frozen_string_literal: true

namespace :dc do
  namespace :users do
    desc 'remove unconfirmed users after x days'
    task :remove_unconfirmed, [:days] => :environment do |_, args|
      abort('Please provide the number of days') if args.days.nil?
      abort('User Confirmation is not enabled') unless Devise.mappings[:user].confirmable?

      days = args.days.to_i
      logger = Logger.new('log/remove_unconfirmed_users.log')

      unconfirmed_users = DataCycleCore::User.unconfirmed_for(days)
      count = unconfirmed_users.count
      logger.info "Starting to remove #{count} unconfirmed users older than #{days} days (cutoff date: #{Time.current - days.days})"

      unconfirmed_users.find_each do |user|
        logger.info "Removing unconfirmed user: #{user.id}, confirmation sent at: #{user.confirmation_sent_at})"
        user.destroy
      end

      logger.info "Finished removing #{count} unconfirmed users."
    end
  end
end
