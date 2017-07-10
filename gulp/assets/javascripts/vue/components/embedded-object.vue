<template>
  <div class="content-object-item" :id="embeddedObjectKey + '_item_' + index">
    <slot name="embedded-item" :index="index" :start-index="startIndex"></slot>
  </div>
</template>

<script>
import ObjectBrowser from './object-browser.vue'

export default {
  props: {
    embeddedObjectKey: {
      type: String
    },
    index: {
      type: Number,
      default: 0
    }
  },
  components: {
    ObjectBrowser
  },
  data() {
    return {
    }
  },
  mounted() {
    this.changeIDs($(this.$el), this.index);
    $(this.$el).trigger('clone-added');
    var elem = this.$el;
    this.$root.$on('objects-saved', function (data) {
      var idx = String(data.id);
      idx = parseInt(idx.match(/\d+/));
      console.log(idx);
      console.log('input[name="' + data.name + '"]');
      $(elem).find('input[name="' + data.name + '"]').attr('name', function (i, txt) {
        return txt.replace(/\d+/, idx);
      });
    });
  },
  created() {
  },
  methods: {
    changeIDs(clone, newID) {

      clone.attr('id', function (i, txt) {
        return txt.replace(/\d+/, newID);
      });

      clone.find('label[for]').attr('for', function (i, txt) {
        return txt.replace(/\d+/, newID);
      });

      clone.find('input[name]').attr('name', function (i, txt) {
        return txt.replace(/\d+/, newID);
      }).val('');

      clone.find('input[id]').attr('id', function (i, txt) {
        return txt.replace(/\d+/, newID);
      }).val('');

      clone.find('.quill-editor').attr('id', function (i, txt) {
        return txt.replace(/\d+/, newID);
      }).attr('data-hidden-field-id', function (i, txt) {
        return txt.replace(/\d+/, newID);
      });
      clone.find('.quill-editor').html('').siblings('.ql-toolbar').remove();

      clone.find('.object-browser').attr('id', function (i, txt) {
        return txt.replace(/\d+/, newID);
      });

      return clone;
    }

  }
}
</script>