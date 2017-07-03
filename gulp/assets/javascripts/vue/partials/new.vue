<template>
  <div>
    <slot name="new-item"></slot>
  </div>
</template>

<script>
export default {
  props: {
  },
  mounted() {
    var browser = this;
    $('div.new-item form').on('submit', function (e) {
      e.preventDefault();

      var url = $(this).attr('action');
      var formData = $(this).serializeArray();

      browser.createNewItem(this, formData, url);
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
        .done(function (data) {
          browser.$emit('add', data);
        });
    }
  }
}
</script>
