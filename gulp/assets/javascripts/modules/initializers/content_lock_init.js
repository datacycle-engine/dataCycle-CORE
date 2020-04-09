// Lock Content when accessing the edit view
let ContentLock = require('../components/content_lock');

module.exports.initialize = function ($) {
  let locks = [];
  $('.content-lock').each((_, element) => {
    locks.push(new ContentLock(element, $(element).hasClass('submit-edit-form')));
  });
};
