// Bulk Delete with Action Cable
let ActionCable = require('actioncable');
let CalloutHelpers = require('./../helpers/callout_helpers');

module.exports.initialize = function() {
  if ($('.bulk-delete-button').length) {
    let deleteButton = $('.bulk-delete-button');
    let actionCable = ActionCable.createConsumer();
    let bulkDeleteChannel = actionCable.subscriptions.create(
      {
        channel: 'DataCycleCore::WatchListBulkDeleteChannel',
        watch_list_id: deleteButton.data('id')
      },
      {
        received: data => {
          if (!deleteButton.prop('disabled')) $.rails.disableFormElement(deleteButton);
          if (data.progress !== undefined) {
            let progress = Math.round((data.progress * 100) / data.items);
            deleteButton.find('.progress-value').text(progress + '%');
            deleteButton.find('.progress-bar > .progress-filled').css('width', 'calc(' + progress + '% - 1rem)');
          }
          if (data.redirect_path !== undefined) {
            deleteButton.removeAttr('data-disable-with');
            window.location.href = data.redirect_path;
          }
        }
      }
    );
  }
};
