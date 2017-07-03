<template>
  <div id="object-browser" data-overlay="false" class="full reveal without-overlay" data-reveal>
    <div class="object-browser-header">
      <h4>
        <i class="fa fa-files-o" aria-hidden="true"></i> Medien auswählen
      </h4>
      <button v-if="createItem" data-open="newItem" class="new-item-button button">
        <i class="fa fa-plus"></i>
      </button>
      <div v-if="createItem" data-overlay="false" class="reveal without-overlay new-item" id="newItem" data-reveal>
        <new v-on:add="addItem" v-if="showNew">
          <template scope="newItem" slot="new-item">
            <slot name="new-item"></slot>
          </template>
        </new>
      </div>
      <button class="close-object-browser" @click.prevent="$emit('close')">
        <i aria-hidden="true" class="fa fa-times"></i>
      </button>
      <div class="button save-object-browser" @click.stop="save">
        <span class="button-title" v-if="totalChosen > 0">
          <strong>{{ totalChosen }}</strong>{{ totalChosen > 0 ? " Element" + (totalChosen == 1 ? "" : "e") + " auswählen" : "Keine Elemente auswählen" }}</span>
        <span class="button-title" v-else>Keine Elemente auswählen</span>
        <div class="chosen-items" v-if="totalChosen > 0">
          <div @click.stop="activeItem = item" class="chosen-item" v-for="item in chosenItems">
            <chosen :item="item" :headline="headline(item)"></chosen>
            <span class="remove" @click.stop="toggleActive(item)">
              <i aria-hidden="true" class="fa fa-times"></i>
            </span>
          </div>
        </div>
      </div>
  
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
      <div v-else class="item" v-for="item in items" @click.prevent="toggleActive(item)" v-bind:class="{ active: isActive(item) }">
        <slot name="item" :item="item"></slot>
      </div>
  
      <pagination :current-page="currentPage" :items-per-page="itemsPerPage" :total-items="totalItems" @page-changed="pageChanged">
      </pagination>
    </div>
    <detail :item="activeItem" :headline="headline(activeItem)" class="item-info"></detail>
  </div>
</template>

<script>
import Pagination from './pagination.vue'
import Detail from './../partials/detail.vue'
import Chosen from './../partials/chosen.vue'
import New from './../partials/new.vue'

export default {
  components: { Pagination, Detail, Chosen, New },
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
    },
    selectOne: {
      type: Boolean,
      default: false
    },
    createItem: {
      type: Boolean,
      default: false
    }
  },
  mounted() {
    var $modal = $('#object-browser').foundation();
    $modal.foundation('open');
    $('.reveal-blur').addClass("show");
    window.scrollTo(0, 0);

    $('#object-browser').on('closed.zf.reveal', function (e) {
      this.$emit('close');
    }.bind(this));

    $('.new-item').on('closed.zf.reveal', function (e) {
      $('body').addClass('is-reveal-open');
      this.showNew = false;
      e.stopPropagation();
    }.bind(this));

    $('.new-item').on('open.zf.reveal', function (e) {
      this.showNew = true;
    }.bind(this));
  },
  beforeDestroy() {
    $('.new-item').remove();
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
      chosenItems: this.preChosenItems.slice(0),
      showNew: false
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
      } else {
        if (this.selectOne) this.chosenItems = [];
        this.chosenItems.push(item);
      }
    },
    compareIndex(array, item) {
      return array.findIndex(function (chosen) {
        return item.id == chosen.id;
      });
    },
    isActive(item) {
      var chosenIndex = this.compareIndex(this.chosenItems, item);
      if (chosenIndex >= 0) return true;
      else return false;
    },
    save() {
      this.$emit('save', this.chosenItems);
      this.$emit('close');
    },
    headline(item) {
      if (this.objectType == "Autor") return item.givenName + " " + item.familyName;
      else if (item != undefined && item.content != undefined) return item.content.headline;
      else return undefined;
    },
    addItem(item) {
      this.items.push(item);
      $('#newItem').foundation('close');
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
