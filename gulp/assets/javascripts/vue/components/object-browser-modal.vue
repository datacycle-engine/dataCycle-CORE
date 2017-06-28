<template>
  <div id="object-browser" data-overlay="false" class="full reveal without-overlay" data-reveal>
    <div class="object-browser-header">
      <h4>
        <i class="fa fa-files-o" aria-hidden="true"></i> Medien auswählen
      </h4>
      <button class="close-object-browser" @click.prevent="$emit('close')">
        <i aria-hidden="true" class="fa fa-times"></i>
      </button>
      <button class="button save-object-browser" @click="save">
        <span class="button-title" v-if="totalChosen > 0">
          <strong>{{ totalChosen }}</strong>{{ totalChosen > 0 ? " Element" + (totalChosen == 1 ? "" : "e") + " auswählen" : "Keine Elemente auswählen" }}</span>
        <span class="button-title" v-else>Keine Elemente auswählen</span>
        <div class="chosen-items" @click.stop v-if="totalChosen > 0">
          <div @click.prevent="activeItem = item" class="chosen-item" v-for="item in chosenItems">
            <chosen :item="item"></chosen>
            <span class="remove" @click.prevent="toggleActive(item)">
              <i aria-hidden="true" class="fa fa-times"></i>
            </span>
          </div>
        </div>
      </button>
  
      <input v-model.lazy="searchTerm" placeholder="Volltext Suche" autofocus id="object-browser-search">
      <span id="item-count" v-if="totalItems > 0">{{ totalItems }}</span>
  
    </div>
    <div id="media-content" class="items">
      <pagination :current-page="currentPage" :items-per-page="itemsPerPage" :total-items="totalItems" @page-changed="pageChanged">
      </pagination>
  
      <div v-if="loading" class="loading">
        <i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>
      </div>
      <div v-else-if="items.length == 0" class="no-entries">Keine Einträge gefunden</div>
      <div v-else class="item" v-for="item in items" @click.prevent="toggleActive(item)" v-bind:class="{ active: item.active }">
        <slot name="item" :item="item"></slot>
      </div>
  
      <pagination :current-page="currentPage" :items-per-page="itemsPerPage" :total-items="totalItems" @page-changed="pageChanged">
      </pagination>
    </div>
    <detail :item="activeItem" class="item-info"></detail>
  </div>
</template>

<script>
import Pagination from './pagination.vue'
import Detail from './../partials/detail.vue'
import Chosen from './../partials/chosen.vue'

export default {
  components: { Pagination, Detail, Chosen },
  props: {
    objectType: {
      type: String,
      default: "Bilder"
    },
    url: {
      type: String,
      default: "/"
    },
    preChosenItems: {
      type: Array,
      default: []
    }
  },
  mounted() {
    //this.chosenItems = this.preChosenItems;
    var $modal = $('#object-browser').foundation();
    $modal.foundation('open');
    $('.reveal-blur').addClass("show");
    window.scrollTo(0, 0);
  },
  beforeDestroy() {
    var $modal = $('#object-browser');
    $modal.foundation('close');
    $('.reveal-blur').removeClass("show");
  },
  data() {
    return {
      searchTerm: '',
      loading: true,
      items: [],
      itemsPerPage: 15,
      currentPage: 1,
      activeItem: {},
      totalItems: 0,
      chosenItems: this.preChosenItems.slice(0)
    }
  },
  methods: {
    pageChanged(pageNum) {
      this.currentPage = pageNum
    },
    toggleActive(item) {
      this.activeItem = item;
      var chosenIndex = this.compareIndex(this.chosenItems, item);
      var index = this.compareIndex(this.items, item);

      if (chosenIndex >= 0) {
        this.chosenItems.splice(chosenIndex, 1);
        if (this.items[index] != undefined) this.items[index].active = false;
      } else {
        this.chosenItems.push(item);
        this.items[index].active = true;
      }
    },
    compareIndex(array, item) {
      return array.findIndex(function (chosen) {
        return item.id == chosen.id;
      });
    },
    addActive() {
      this.items.forEach(function (item) {
        if (this.compareIndex(this.chosenItems, item) >= 0) item.active = true;
        else {
          if (this.objectType == "Autor") item.content.headline = item.givenName + " " + item.familyName;
          item.active = false;
        }
      }, this);
    },
    save() {
      this.$emit('save', this.chosenItems);
      this.$emit('close');
    }
  },
  asyncComputed: {
    filteredItems: {
      get() {
        var self = this;
        this.loading = true;
        this.items = [];
        return $.getJSON(this.url, { search: this.searchTerm, page: this.currentPage, per: this.itemsPerPage, type: this.objectType }).done(function (json_data) {
          this.totalItems = json_data.total;
          this.items = json_data.results;
          this.loading = false;
          this.addActive();
          return this.items;
        }.bind(this));
      },
      watch() {
        this.searchTerm
      }
    }
  },
  computed: {
    totalChosen() {
      return this.chosenItems.length;
    }
  }
}
</script>
