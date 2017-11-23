// Datalist
module.exports.initialize = function () {

  $('.ajax-datalist').each(function () {
    var list = $(this).attr('list');
    $("#" + list).html('');
    $.get('/' + list + '/search', function (data) {
      for (var i = 0; i < data.length; i++) {
        $("#" + list).append('<option data-familyname="' + data[i].family_name + '" data-givenname="' + data[i].given_name + '" value="' + data[i].email + '">');
      }
    });

    $(this).on('input', function (ev) {
      $.get('/' + list + '/search', {
        q: $(this).val()
      }, function (data) {
        $("#" + list).html('');
        for (var i = 0; i < data.length; i++) {
          $("#" + list).append('<option data-familyname="' + data[i].family_name + '" data-givenname="' + data[i].given_name + '" value="' + data[i].email + '">');
        }
        if ($("#" + list + " option[value='" + $(this).val() + "']").length > 0) {
          var $user = $("#" + list + " option[value='" + $(this).val() + "']");
          $(this).siblings('input[id$=given_name]').first().val($user.data('givenname')).prop('readonly', true);
          $(this).siblings('input[id$=family_name]').first().val($user.data('familyname')).prop('readonly', true);
        } else {
          $(this).siblings('input[id$=given_name]').first().prop('readonly', false);
          $(this).siblings('input[id$=family_name]').first().prop('readonly', false);
        }
      }.bind(this));

    });
  });

};
