<template>
  <div>
    <div class="object-thumbs" v-if="existingItems.length > 0">
      <slot name="item" v-for="item in existingItems" :item="item" :remove="remove"></slot>
    </div>
    <div class="object-thumbs" v-else>
      <input type="hidden" :name="hiddenName">
    </div>
    <transition name="fade">
      <keep-alive>
        <object-browser-modal v-if="showModal" @save="save" :object-type="objectType" :object-label="objectLabel" url="/objectbrowser" :preChosenItems="existingItems" :select-one="selectOne" @close="showModal = false" :create-item="createItem" :min="min" :max="max">
          <template scope="props" slot="item">
            <slot name="item" :item="props.item"></slot>
          </template>
          <template scope="newItem" slot="new-item">
            <slot name="new-item"></slot>
          </template>
        </object-browser-modal>
      </keep-alive>
    </transition>
    <button class="button" id="show" @click.prevent="showModal = true">
      <i class="fa fa-plus"></i>
    </button>
  </div>
</template>

<script>
import ObjectBrowserModal from './object-browser-modal.vue'
import Error from './../mixins/errors.js'

export default {
  mixins: [Error],
  props: {
    existing: {
      type: Array
    },
    objectType: {
      type: String
    },
    objectLabel: {
      type: String
    },
    createItem: {
      type: Boolean,
      default: false
    },
    hiddenName: {
      type: String
    },
    min: {
      type: Number,
      default: 0
    },
    max: {
      type: Number,
      default: 0
    }
  },
  components: {
    ObjectBrowserModal
  },
  data() {
    return {
      showModal: false,
      existingItems: []
    }
  },
  created() {
    this.existingItems = this.existing;
  },
  methods: {
    remove(item, event) {
      if (this.min > 0 && this.existingItems.length <= this.min) return this.renderError("min", this.min, event, this.objectType);
      var index = this.compareIndex(this.existingItems, item);
      if (index >= 0) {
        this.existingItems.splice(index, 1);
      }
    },
    compareIndex(array, item) {
      return array.findIndex(function (chosen) {
        return item.id == chosen.id;
      });
    },
    save(data) {
      this.existingItems = data.slice(0);
      var parentID = $(this.$el).closest('.object-browser').attr('id');
      this.$root.$emit('objects-saved', { name: this.hiddenName, id: parentID });
    }
  }
}
</script>