// Object Browser
// todo: object browser component

var formatBytes = require('./../components/format_bytes');
var formatDate = require('./../components/format_date');

module.exports.initialize = function () {

  $('.object-browser').on('click', '.delete-thumbnail', function (ev) {
    $(this).parent('.media.thumbnail').remove();
    ev.preventDefault();
  });

  $('.media-thumbs').on('click', '.mediabrowser', function (ev) {
    var media_type = $(this).data('media-type');

    var $modal = $('#mediabrowser');
    var $media_content = $('#media-content');

    $.ajax({
      url: '/objectbrowser',
      dataType: "json"
    })
      .done(function (data) {

        $modal.foundation('open');
        render_media(data, $media_content);

        $('#mediabrowser .media').on('click', function (event) {
          $(this).toggleClass('add');
          if ($(this).is('.add')) {
            var $active_item = $(this);
            $("#media-info .add-metadata").each(function () {
              if ($(this).attr('id') == "thumb-url") $(this).html("<img src='" + $active_item.data($(this).attr('id')) + "'>");
              else if ($(this).attr('id') == "media-file-url") $(this).html("<a href='" + $active_item.data($(this).attr('id')) + "' target='_blank'>" + $active_item.data($(this).attr('id')) + "</a>");
              else $(this).html($active_item.data($(this).attr('id')));
            });
          }
          else {
            $("#media-info .add-metadata").html('');
          }
          var numItems = $('.media.add').length;
          $("#close-media-browser").html("<strong>" + numItems + "</strong> Elemente auswählen");
          if (numItems == 1) { $("#close-media-browser").html("<strong>" + numItems + "</strong> Element auswählen"); }
          if (numItems == 0) { $("#close-media-browser").html("Keine Elemente auswählen"); }
          event.preventDefault();
        });

        $('#mediabrowser .close-button').on('click', function (ev) {
          $('#media-content').html('');
          $("#close-media-browser").remove();
        });

        $('#mediabrowser #close-media-browser').on('click', function (event) {
          var $thumbs = $('#creative_work_datahash_image .media-thumbs');
          var $addButton = $('#creative_work_datahash_image .media-thumbs button.mediabrowser').prop('outerHTML');
          $thumbs.html('');
          $('#mediabrowser .add').each(function (index) {
            var id = $(this).data('media-id');
            var thumbUrl = $(this).data('thumb-url');
            var name = $(this).data('media-name');
            var html = "<div class='media thumbnail' style='background-image: url(" + thumbUrl + ");'><a class='delete-thumbnail' href='#'><i aria-hidden='true' class='fa fa-times'></i></a><span class='caption'>" + name + "</span><input type='hidden' name='creative_work[datahash][image][]' value='" + id + "' />"
            //var html = "<div class='item'><a class='delete-item' href='#'><i aria-hidden='true' class='fa fa-times'></i></a><strong>"+name+"</strong><br /><img src='"+thumbUrl+"' />";
            $thumbs.append(html);
          });
          $thumbs.append($addButton);
          $modal.foundation('close');
          $('#media-content').html('');
          $("#close-media-browser").remove();
          event.preventDefault();
        });
      });

    ev.preventDefault();
  });
  $('#main-menu button.button').on('click', function (ev) {
    $('#mediabrowser').foundation('close');
    $('#media-content').html('');
    $("#close-media-browser").remove();
  });

  function render_media(data, $media_content) {
    for (var i = 0; i < data.length; i++) {
      if (data[i].metadata.validation != undefined) {
        if (data[i].metadata.validation.name == "Bild" && data[i].metadata.thumbnailUrl != undefined) {
          var name = "";
          if (data[i].content != null && data[i].content.name != null) name = data[i].content.name;
          var html = "<a class='media thumbnail'";
          html += " data-media-id='" + data[i].id + "'";
          html += " data-media-dimensions='" + data[i].metadata.width + " x " + data[i].metadata.height + "'";
          html += " data-media-format='" + data[i].metadata.fileFormat + "'";
          html += " data-media-license='" + data[i].metadata.license + "'";
          html += " data-media-size='" + formatBytes.format(data[i].metadata.contentSize) + "'";
          html += " data-media-file-url='" + data[i].metadata.contentUrl + "'";
          html += " data-media-date-modified='" + formatDate.format(data[i].metadata.dateCreated) + "'";
          html += " data-media-date-created='" + formatDate.format(data[i].metadata.dateModified) + "'";
          html += " data-thumb-url='" + data[i].metadata.thumbnailUrl + "'";
          html += " data-media-name='" + name + "'";
          html += " style='background-image: url(" + data[i].metadata.thumbnailUrl + ");'>";
          html += "<span class='caption'>" + name + "</span></a>"
          $media_content.append(html);
        }
      }
    }
    // mark existing ones
    var numbObjects = $('.object-browser .media-thumbs .media input[type=hidden]').length;
    var buttonText = "Keine Elemente auswählen";
    if (numbObjects == 1) buttonText = "1 Element auswählen";
    else if (numbObjects > 1) buttonText = numbObjects + " Element auswählen";
    $('.object-browser .media-thumbs .media input[type=hidden]').each(function (index) {
      var id = $(this).val();
      $('a[data-media-id=' + id + ']').addClass('add');
    });
    $("#mediabrowser h4").append("<button data-close type='button' class='button' id='close-media-browser' style='display: block;'><span aria-hidden='true'>" + buttonText + "</span></button>");
  }

};