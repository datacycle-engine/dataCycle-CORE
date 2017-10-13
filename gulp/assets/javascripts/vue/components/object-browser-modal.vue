<template>
  <div id="object-browser" data-overlay="false" class="full reveal without-overlay" data-reveal data-v-offset="0">
    <div class="object-browser-header">
      <span class="search-icon">
        <i class="fa fa-search" aria-hidden="true"></i>
      </span>
      <input v-model.lazy="searchTerm" placeholder="Volltext Suche" autofocus id="object-browser-search">
      <span id="item-count" v-if="totalItems > 0">{{ totalItems }}</span>

    </div>
    <div id="media-content" class="items">

      <div v-if="items.length == 0 && !loading" class="no-entries">Keine Einträge gefunden</div>
      <div v-else class="item" v-for="item in items" :key="item" @click.prevent="toggleActive(item, $event)" v-bind:class="{ active: isActive(item) }">
        <slot name="item" :item="item"></slot>
      </div>
      <div v-if="loading" class="loading">
        <i class="fa fa-circle-o-notch fa-spin fa-3x fa-fw"></i>
      </div>

    </div>
    <component :is="objectType + '_detail'" :item="activeItem" :link="editUrl" class="item-info">
    </component>

    <div class="object-browser-footer">
      <div class="chosen-items items">
        <div class="chosen-items-container">
          <div @click.stop="activeItem = item" v-for="item in chosenItems" :key="item">
            <slot name="item" :item="item" :remove="toggleActive"></slot>
          </div>
        </div>
      </div>
      <div class="buttons">
        <span class="button-title" v-if="totalChosen > 0">
          <sup>
            <strong>{{ totalChosen }}</strong>{{ totalChosen > 0 ? " Element" + (totalChosen == 1 ? "" : "e") + " auswählen" : "Keine Elemente auswählen" }}
            <i class="fa fa-chevron-right" aria-hidden="true"></i>
          </sup>
        </span>
        <span class="button-title" v-else>
          <sup>Keine Elemente auswählen
            <i class="fa fa-chevron-right" aria-hidden="true"></i>
          </sup>
        </span>
        <a class="button-prime success small save-object-browser" @click.stop="save">
          <i class="fa fa-check" aria-hidden="true"></i>
        </a>
        <button v-if="createItem" :data-open="newId" class="new-item-button button-prime small">
          <i class="fa fa-plus"></i>
        </button>
        <button class="button-prime small close-object-browser" @click.prevent="$emit('close')">
          <i aria-hidden="true" class="fa fa-times"></i>
        </button>
        <new v-on:add="addItem" :object-type="objectType">
          <template scope="newItem" slot="new-item">
            <slot name="new-item"></slot>
          </template>
        </new>
      </div>
    </div>
  </div>
</template>

<script>
import Pagination from './pagination.vue'
import Error from './../mixins/errors.js'
import Components from './../partials'

export default {
  mixins: [Error, Components],
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

    $('.new-item').on('closed.zf.reveal', function(e) {
      $('body').addClass('is-reveal-open');
      e.stopPropagation();
    }.bind(this));

    $('.new-item').on('open.zf.reveal', function(e) {
      if (this.newModal.find('form').length > 0) this.newModal.find('form')[0].reset();
      this.newModal.find('input[type=submit]').removeAttr('disabled');

    }.bind(this));

    $(this.$el).find('#media-content').first().on('scroll', function(event) {
      if (this.items.length < this.totalItems) {
        var elem = $(event.currentTarget);

        if (elem[0].scrollHeight - elem.scrollTop() - 100 <= elem.outerHeight() && !this.loading) {
          this.currentPage += 1;
        }
      }
    }.bind(this));

  },
  activated() {
    this.chosenItems = this.preChosenItems.slice(0);
    if (this.chosenItems.length > 0) this.activeItem = this.chosenItems[0];
    this.scrollTop = $(window).scrollTop();
    this.modal.foundation('open');
    $('.reveal-blur').addClass("show");
    window.scrollTo(0, 0);

    // set breadcrumb link + text
    var text = $('.breadcrumb ul li:last-child').html();
    $('.breadcrumb ul li:last-child').html('<a class="close-object-browser" href="#">' + text + '</a><i class="fa fa-angle-right breadcrumb-separator" aria-hidden="true"></i>');
    $('.breadcrumb ul').append('<li><span class="breadcrumb-text"><i><i class="fa fa-files-o" aria-hidden="true"></i>' + this.objectLabel + ' auswählen</i></span></li>');

    $('.breadcrumb ul li').on('click', '.close-object-browser', function(e) {
      e.preventDefault();
      this.$emit('close');
    }.bind(this));
  },
  deactivated() {
    $(window).scrollTop(this.scrollTop);
    if (this.newModal != '') this.newModal.foundation('close');
    this.modal.foundation('close');
    $('.reveal-blur').removeClass("show");

    // remove breadcrumb link + text
    $('.breadcrumb ul li:last-child').remove();
    var text = $('.breadcrumb ul li:last-child a.close-object-browser').html();
    $('.breadcrumb ul li:last-child').html(text);
  },
  watch: {
    searchTerm(val) {
      this.items = [];
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
      return array.findIndex(function(chosen) {
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
      if (item.id != undefined && item.errors == undefined) {
        this.items.push(item);
        if (this.newModal != '') this.newModal.foundation('close');
      }
    }
  },
  asyncComputed: {
    filteredItems: {
      get() {
        var self = this;
        this.loading = true;
        return $.getJSON(self.url, { search: self.searchTerm, page: self.currentPage, per: self.itemsPerPage, type: self.objectType }).done(function(json_data) {
          self.totalItems = json_data.total;
          var items = self.items.concat(json_data.results);
          self.items = items.slice(0);
          self.loading = false;
          return self.items;
        });
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
