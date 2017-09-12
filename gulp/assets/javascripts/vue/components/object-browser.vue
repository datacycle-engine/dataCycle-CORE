<template>
  <div>
    <div class='confirmation' v-if="confirm">
      <span v-html="confirmText"></span>
      <div class="buttons">
        <button class='button abort' @click.prevent="confirm = false">Abbrechen</button>
        <button class='button ok' @click.prevent="confirmed">Ok</button>
      </div>
    </div>

    <div class="object-thumbs" v-if="existingItems.length > 0">
      <div v-for="item in existingItems" :key="item">
        <slot name="item" :item="item" :remove="remove" :uid="_uid" :data-open="revealLink ? 'media-reveal-'+item.id+'_'+_uid : ''" :readonly="readonly"></slot>
      </div>
    </div>
    <div class="object-thumbs" v-else>
      <input type="hidden" :name="hiddenName">
    </div>
    <transition name="fade">
      <keep-alive>
        <object-browser-modal v-if="showModal" @save="save" :object-type="objectType" :object-label="objectLabel" :url="url" :preChosenItems="existingItems" :select-one="selectOne" :new-id="newId" @close="showModal = false" :create-item="createItem" :min="min" :max="max">
          <template scope="props" slot="item">
            <slot name="item" :item="props.item" :remove="props.remove"></slot>
          </template>
          <template scope="newItem" slot="new-item">
            <slot name="new-item"></slot>
          </template>
        </object-browser-modal>
      </keep-alive>
    </transition>
    <button v-if="!readonly" class="button" id="show" @click.prevent="showModal = true">
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
    objectClass: {
      type: String,
      default: 'DataCycleCore::CreativeWork'
    },
    newId: {
      type: String
    },
    objectLabel: {
      type: String
    },
    createItem: {
      type: Boolean,
      default: false
    },
    revealLink: {
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
    },
    readonly: {
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
      existingItems: [],
      url: '/objectbrowser',
      confirm: false,
      confirmData: [],
      confirmText: ""
    }
  },
  created() {
    this.existingItems = this.existing;
  },
  mounted() {
    $(this.$el).find('.media-preview').foundation();
    if (!this.readonly) {
      $(this.$el).on('import-data', function(ev, data) {
        $.getJSON(this.url + "/find", { ids: data.ids, class: this.objectClass }).done(function(json_data) {
          if (this.getDelta(json_data, this.existingItems).length > 0) {
            if (this.max == 0 || this.existingItems.length < this.max) {
              this.mergeArrays(this.existingItems, json_data);
            }
            else this.confirmation(json_data, "Auswahl überschreiben?");
          }
        }.bind(this));
      }.bind(this));
    }
  },
  methods: {
    remove(item, event) {
      if (this.min > 0 && this.existingItems.length <= this.min) return this.renderError("min", this.min, event, this.objectType);
      var index = this.compareIndex(this.existingItems, item);
      if (index >= 0) {
        this.removeOverlay([this.existingItems[index]]);
        this.existingItems.splice(index, 1);
      }
    },
    mergeArrays(arr1, arr2) {
      var combined = arr1;
      var rest = 0;
      for (var i = 0; i < arr2.length; i++) {
        var idx = this.compareIndex(arr1, arr2[i]);
        if (idx < 0 && this.max > 0 && combined.length < this.max) combined.push(arr2[i]);
        else if (idx < 0 && this.max == 0) combined.push(arr2[i]);
        else if (idx < 0 && combined.length >= this.max) rest++;
      }
      if (rest > 0) {
        this.confirmation(combined, "Zu viele hinzugefügt. " + rest + " werden nicht hinzugefügt.<br />Trotzdem fortfahren?");
      } else {
        this.save(combined);
      }
    },
    getDelta(arr1, arr2) {
      var delta = [];
      var longer = arr1.length >= arr2.length ? arr1 : arr2;
      var shorter = arr1.length >= arr2.length ? arr2 : arr1;

      for (var i = 0; i < longer.length; i++) {
        if (this.compareIndex(shorter, longer[i]) < 0) delta.push(longer[i]);
      }
      return delta;
    },
    compareIndex(array, item) {
      return array.findIndex(function(chosen) {
        return item.id == chosen.id;
      });
    },
    removeOverlay(delta) {
      for (var i = 0; i < delta.length; i++) {
        $('#media-reveal-' + delta[i].id + '_' + this._uid).parent('.reveal-overlay').remove();
      }
    },
    confirmation(data, text) {
      this.confirmText = text;
      this.confirmData = data;
      this.confirm = true;
    },
    confirmed() {
      this.confirm = false;
      this.save(this.confirmData);
    },
    save(data) {
      this.removeOverlay(this.getDelta(this.existingItems, data));
      this.existingItems = data.slice(0);
      this.$parent.$emit('objects-saved', { name: this.hiddenName });
      this.$nextTick(function() {
        $(this.$el).find('.media-preview').foundation();
        $(this.$el).trigger('media_previews_added');
      });
    }
  }
}
</script>