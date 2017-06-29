<template>
  <div class="object-browser">
    <div class="object-thumbs">
      <slot name="item" v-for="item in existingItems" :item="item" :remove="remove" :select-one="selectOne"></slot>
    </div>
    <transition name="fade">
      <object-browser-modal v-if="showModal" v-on:save="save" :object-type="objectType" url="/objectbrowser" :preChosenItems="existingItems" :select-one="selectOne" @close="showModal = false">
        <template scope="props" slot="item">
          <slot name="item" :item="props.item"></slot>
        </template>
      </object-browser-modal>
    </transition>
    <button class="button" id="show" @click.prevent="showModal = true">
      <i class="fa fa-plus"></i>
    </button>
  </div>
</template>

<script>
import ObjectBrowserModal from './object-browser-modal.vue'

export default {
  props: {
    existing: {
      type: Array
    },
    objectType: {
      type: String
    },
    selectOne: {
      type: Boolean,
      default: false
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
    // if (this.objectType == "Autor") {
    //   for (var i = 0; i < this.existingItems.length; i++) {
    //     this.existingItems[i].content.headline = this.existingItems[i].givenName + " " + this.existingItems[i].familyName;
    //   }
    // }
  },
  methods: {
    remove(item) {
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
      this.existingItems = data;
    }
  }
}
</script>