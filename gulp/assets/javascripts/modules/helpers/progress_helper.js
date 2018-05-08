// Progressbar Helper
module.exports = {
  progress: (event, container) => {
    var percentage = (event.loaded * 100) / event.total;
    if (container.hasClass('progress-container')) {
      container.find('.progressbar > .progressbar-meter').css('width', percentage + '%');
    } else {
      var text = container.html();
      container.html('').addClass('progress-container');
      container.append('<span class="progresstitle">' + text + '</span><span class="progressbar"><span class="progressbar-meter style="width: ' + percentage + '%;"></span></span>');
    }

    if (percentage >= 100) {
      var text = container.find('.progresstitle').html();
      container.find('.progressbar').fadeOut(500, () => {
        container.html(text).removeClass('progress-container');
      });
    }
  }
};
