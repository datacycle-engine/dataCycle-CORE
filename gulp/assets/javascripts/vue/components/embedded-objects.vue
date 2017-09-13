<template>
  <div>
    <embedded-object :embedded-object-key="embeddedObjectKey" v-for="idx in embeddedObjects" :key="idx" :index="idx" @remove="removeItem(idx)" :readonly="readonly">
      <template scope="props" slot="embedded-item">
        <slot name="embedded-item"></slot>
      </template>
    </embedded-object>
    <button v-if="(embeddedObjectsLength + preLength) < max || max == 0" :id="'add_' + embeddedObjectKey" class="button addContentObject" @click.prevent="addItem" :disabled="readonly">
      {{ label }} hinzufügen
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
    },
    label: {
      type: String
    },
    readonly: {
      type: Boolean,
      default: false
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
    $(this.$el).parent().on('remove-embedded-object', '.content-object-item', function() {
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
      this.embeddedObjects = this.embeddedObjects.filter(function(e) { return e !== item });
    }
  }
}
</script>