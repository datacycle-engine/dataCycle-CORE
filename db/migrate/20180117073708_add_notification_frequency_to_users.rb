class AddNotificationFrequencyToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :notification_frequency, :string, default: 'always'
  end
end
