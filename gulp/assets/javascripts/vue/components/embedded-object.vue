<template>
  <div class="content-object-item" :id="embeddedObjectKey + '_item_' + index">
    <button @click.prevent="$emit('remove')" class="button removeContentObject">
      <i class="fa fa-times"></i>
    </button>
    <slot name="embedded-item"></slot>
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
      parentIndex: []
    }
  },
  mounted() {
    if (this.$parent.$parent != undefined && this.$parent.$parent.$options._componentTag == this.$options._componentTag) {
      this.parentIndex = this.$parent.$parent.parentIndex.slice(0);
    } else if ($(this.$el).parents('.content-object-item').length > 0) {
      var object = this;
      $(this.$el).parents('.content-object-item').each(function () {
        object.parentIndex.unshift(parseInt($(this).attr('id').match(/\d+/)[0]));
      });
    }
    this.parentIndex.push(this.index);

    this.changeIDs();

    $(this.$el).trigger('clone-added');

    this.$on('objects-saved', function (data) {
      this.$nextTick(function () {
        $(this.$el).find("input[name^='" + data.name + "']").attr('name', this.changeID);
      });
    }.bind(this));
  },
  created() {
  },
  methods: {
    changeIDs() {
      $(this.$el).attr('id', this.changeID);
      $(this.$el).find('label[for]').attr('for', this.changeID);
      $(this.$el).find('input[name]').attr('name', this.changeID).val('');
      $(this.$el).find('input[id]').attr('id', this.changeID).val('');
      $(this.$el).find('.quill-editor').attr('id', this.changeID).attr('data-hidden-field-id', this.changeID);
      $(this.$el).find('.quill-editor').html('').siblings('.ql-toolbar').remove();
      $(this.$el).find('.object-browser').attr('id', this.changeID);
      $(this.$el).find('.slider span').attr('aria-controls', this.changeID);
    },
    changeID(pos, txt) {
      var count = 0;
      return txt.replace(/\d+/g, function (x, i) {
        var replacement;
        if (this.parentIndex[count] != undefined) replacement = this.parentIndex[count];
        else replacement = x;
        count++;
        return replacement;
      }.bind(this));
    }
  }
}
</script>