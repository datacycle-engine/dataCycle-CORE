<template>
  <div id="object-browser" data-overlay="false" class="full reveal without-overlay" data-reveal data-v-offset="0">
    <div class="object-browser-header">
      <h4>
        <i class="fa fa-files-o" aria-hidden="true"></i> {{objectLabel}} auswählen
      </h4>
      <div class="buttons">
        <div class="button save-object-browser" @click.stop="save">
          <span class="button-title" v-if="totalChosen > 0">
            <strong>{{ totalChosen }}</strong>{{ totalChosen > 0 ? " Element" + (totalChosen == 1 ? "" : "e") + " auswählen" : "Keine Elemente auswählen" }}</span>
          <span class="button-title" v-else>Keine Elemente auswählen</span>
          <div class="chosen-items" v-if="totalChosen > 0">
            <div @click.stop="activeItem = item" class="chosen-item" v-for="item in chosenItems" :key="item">
              <component :is="objectType + '_chosen'" :item="item"></component>
              <span class="remove" @click.stop="toggleActive(item, $event)">
                <i aria-hidden="true" class="fa fa-times"></i>
              </span>
            </div>
          </div>
        </div>
        <button v-if="createItem" :data-open="newId" class="new-item-button button">
          <i class="fa fa-plus"></i>
        </button>
        <button class="close-object-browser" @click.prevent="$emit('close')">
          <i aria-hidden="true" class="fa fa-times"></i>
        </button>
        <new v-on:add="addItem">
          <template scope="newItem" slot="new-item">
            <slot name="new-item"></slot>
          </template>
        </new>
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
      <div v-else class="item" v-for="item in items" :key="item" @click.prevent="toggleActive(item, $event)" v-bind:class="{ active: isActive(item) }">
        <slot name="item" :item="item"></slot>
      </div>
  
      <pagination :current-page="currentPage" :items-per-page="itemsPerPage" :total-items="totalItems" @page-changed="pageChanged">
      </pagination>
    </div>
    <component :is="objectType + '_detail'" :item="activeItem" :link="editUrl" class="item-info">
    </component>
  </div>
</template>

<script>
import Pagination from './pagination.vue'
import Error from './../mixins/errors.js'
import Components from './../partials'

export default {
  mixins: [Error, Components],
  components: { Pagination },
  props: {
    objectType: {
      type: String,
      default: "image"
    },
    objectLabel: {
      type: String,
      default: "Bilder"
    },
    newId: {
      type: String
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
  data() {
    return {
      searchTerm: '',
      loading: true,
      items: [],
      itemsPerPage: 25,
      currentPage: 1,
      activeItem: {},
      totalItems: 0,
      chosenItems: this.preChosenItems.slice(0),
      scrollTop: 0,
      modal: '',
      newModal: '',
      editUrl: ''
    }
  },
  mounted() {
    this.modal = $('#object-browser').foundation();
    if ($('#' + this.newId).length > 0) {
      this.newModal = $('#' + this.newId).foundation();
      $('#' + this.newId).parent().css('z-index', '10000');
      this.editUrl = this.newModal.find('form').attr('action');
    }

    $('.new-item').on('closed.zf.reveal', function (e) {
      $('body').addClass('is-reveal-open');
      e.stopPropagation();
    }.bind(this));

    $('.new-item').on('open.zf.reveal', function (e) {
      this.newModal.find('form')[0].reset();
      this.newModal.find('input[type=submit]').removeAttr('disabled');

    }.bind(this));
  },
  activated() {
    this.chosenItems = this.preChosenItems.slice(0);
    this.scrollTop = $(window).scrollTop();
    this.modal.foundation('open');
    $('.reveal-blur').addClass("show");
    window.scrollTo(0, 0);
  },
  deactivated() {
    $(window).scrollTop(this.scrollTop);
    if (this.newModal != '') this.newModal.foundation('close');
    this.modal.foundation('close');
    $('.reveal-blur').removeClass("show");
  },
  watch: {
    searchTerm(val) {
      this.currentPage = 1;
    }
  },
  methods: {
    pageChanged(pageNum) {
      this.currentPage = pageNum
    },
    toggleActive(item, event) {
      this.activeItem = item;

      var chosenIndex = this.compareIndex(this.chosenItems, item);
      var index = this.compareIndex(this.items, item);

      if (chosenIndex >= 0) {
        if (this.min > 0 && this.totalChosen == this.min) return this.renderError("min", this.min, event, this.objectLabel);
        this.chosenItems.splice(chosenIndex, 1);
      } else {
        if (this.max > 1 && this.totalChosen >= this.max) return this.renderError("max", this.max, event, this.objectLabel);
        if (this.max == 1) this.chosenItems = [];
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
    addItem(item) {
      this.items.push(item);
      if (this.newModal != '') this.newModal.foundation('close');
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
