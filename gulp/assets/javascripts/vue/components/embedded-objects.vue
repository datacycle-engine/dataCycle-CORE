<template>
  <div>
    <embedded-object :embedded-object-key="embeddedObjectKey" v-for="idx in embeddedObjects" :key="idx" :index="idx" @remove="removeItem(idx)">
      <template scope="props" slot="embedded-item">
        <slot name="embedded-item"></slot>
      </template>
    </embedded-object>
    <button v-show="(embeddedObjectsLength + preLength) < max || max == 0" :id="'add_' + embeddedObjectKey" class="button addContentObject" @click.prevent="addItem">
      Hinzufügen
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
    max: {
      type: Number,
      default: 0
    }
  },
  components: {
    EmbeddedObject
  },
  data() {
    return {
      embeddedObjects: [],
      nextIndex: 0,
      preLength: 0
    }
  },
  mounted() {
    this.nextIndex = $(this.$el).siblings('.content-object-item').length;

    this.preLength = this.nextIndex;
    $(this.$el).parent().on('remove-embedded-object', '.content-object-item', function () {
      this.preLength--;
    }.bind(this));
  },
  computed: {
    embeddedObjectsLength() {
      return this.embeddedObjects.length;
    }
  },
  methods: {
    addItem() {
      this.embeddedObjects.push(this.nextIndex);
      this.nextIndex++;
    },
    removeItem(item) {
      this.embeddedObjects = this.embeddedObjects.filter(function (e) { return e !== item });
    }
  }
}
</script>