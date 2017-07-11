<template>
  <div>
    <embedded-object :embedded-object-key="embeddedObjectKey" v-for="i in indizes" :index="i+startIndex-1">
      <template scope="props" slot="embedded-item">
        <slot name="embedded-item" :index="index" :start-index="startIndex"></slot>
      </template>
    </embedded-object>
    <button :id="'add_' + embeddedObjectKey" class="button addContentObject" @click.prevent="addItem">
      <i class="fa fa-plus"></i>
    </button>
  
  </div>
</template>

<script>
import EmbeddedObject from './embedded-object.vue'

export default {
  props: {
    embeddedObjectKey: {
      type: String
    },
    startIndex: {
      type: Number,
      default: 0
    }
  },
  components: {
    EmbeddedObject
  },
  data() {
    return {
      indizes: 0
    }
  },
  methods: {
    addItem() {
      this.indizes++;
    }
  }
}
</script>