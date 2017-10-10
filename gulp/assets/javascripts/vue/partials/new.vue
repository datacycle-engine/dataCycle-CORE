<template>
  <div>
    <slot name="new-item"></slot>
  </div>
</template>

<script>
export default {
  props: {
    objectType: {
      type: String,
      default: "image"
    },
  },
  mounted() {
    var browser = this;
    var $reveal = $(this.$el).find('.reveal');
    $('div.new-item form').on('submit', function(e) {
      e.preventDefault();

      var url = $(this).attr('action');
      var formData = $(this).serializeArray();

      if (browser.checkFields(this)) browser.createNewItem(this, formData, url);
    });

    $("div.new-item form input[type=text]:not('.no-validation')").each(function(e) {
      $(this).on('change', function(e) {
        $(this).closest('form').find('input[type=submit]').removeAttr('disabled');
        $(this).closest('.validation-container').find('.single_error').remove();
        browser.checkField(this);
      });
    });

    $reveal.on('open.zf.reveal', function() {
      var iframe = $(this).find('iframe');
      if (iframe.length > 0) {
        iframe.css('visibility', 'hidden');
        iframe[0].src = iframe[0].src;
        iframe.on('load', function() {
          iframe.css('visibility', 'visible');
        });
      }
    });

    $(window).on('message', function() {
      $reveal.foundation('close');
      if (event.data.action == 'import') {
        var AUTH_TOKEN = $('meta[name=csrf-token]').attr('content');
        $.post('/creative_works/import', { authenticity_token: AUTH_TOKEN, type: browser.objectType + "_object", data: event.data.data }, function(data) {
          browser.$emit('add', data);
        });
      }
    });

  },
  beforeDestroy() {
    $('div.new-item form').off('submit');
  },
  methods: {
    createNewItem(form, data, url) {
      var browser = this;
      $.ajax({
        dataType: "json",
        type: "POST",
        url: url,
        data: $.param(data)
      })
        .done(function(data) {
          browser.$emit('add', data);
        });
    },
    checkFields(form) {
      var isValid = true;
      var browser = this;
      $(form).find("input[type=text]:not('.no-validation')").each(function(e) {
        if (browser.checkField(this) == false) isValid = false;
      });
      return isValid;
    },
    checkField(field) {
      if ($(field).val().length == 0) {
        var data = {};
        data.error = ["Feld darf nicht leer sein"];
        $(field).closest('.validation-container').append(this.renderErrorMsg(data, field));
        return false;
      }
      return true;
    },
    renderErrorMsg(data, item) {
      var out = '';
      var item_id = '';
      if (item != null && $(item).attr('id') != undefined) item_id = "id='" + $(item).attr('id') + "_error'";
      else if (item != null && $(item).closest('.form-element').find('label').first().attr('for') != undefined) item_id = "id='" + $(item).closest('.form-element').find('label').first().attr('for') + "_error'";

      var item_label = (item != null) ? $(item).closest('.form-element').find('label').first().html() + ": " : "";
      $.each(data.error, function(key, val) {
        out += "<span " + item_id + "class='single_error'><strong>" + item_label + "</strong>" + val + "</span>";
      });
      return out;
    }
  }
}
</script>
