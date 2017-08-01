<template>
  <ul class="pagination" v-show="totalItems > 0">
    <li v-show="currentPage > 1">
      <a href="#" @click.prevent="pageChanged(1)" aria-label="First" :disabled="currentPage <= 1">
        <span aria-hidden="true">&laquo; Erste</span>
      </a>
    </li>
    <li v-show="currentPage > 1">
      <a href="#" @click.prevent="pageChanged(currentPage-1)" aria-label="Previous" :disabled="currentPage <= 1">
        <span aria-hidden="true">&lsaquo; Vorherige</span>
      </a>
    </li>
    <li v-for="n in paginationRange" :key="n" :class="activePage(n)">
      <a href="#" @click.prevent="pageChanged(n)">{{ n }}</a>
    </li>
    <li v-show="currentPage < lastPage">
      <a href="#" @click.prevent="pageChanged(currentPage+1)" aria-label="Next" :disabled="currentPage >= lastPage">
        <span aria-hidden="true">Nächste &rsaquo;</span>
      </a>
    </li>
    <li v-show="currentPage < lastPage">
      <a href="#" @click.prevent="pageChanged(lastPage)" aria-label="Last" :disabled="currentPage >= lastPage">
        <span aria-hidden="true">Letzte &raquo;</span>
      </a>
    </li>
  </ul>
</template>

<script>

export default {

  props: {
    // Current Page
    currentPage: {
      type: Number,
      required: true
    },
    // Total page
    totalPages: Number,
    // Items per page
    itemsPerPage: Number,
    // Total items
    totalItems: Number,
    // Visible Pages
    visiblePages: {
      type: Number,
      default: 5,
      coerce: (val) => parseInt(val)
    }
  },

  data() {
    return {}
  },

  computed: {
    lastPage() {
      if (this.totalPages) {
        return this.totalPages
      } else {
        return this.totalItems % this.itemsPerPage === 0
          ? this.totalItems / this.itemsPerPage
          : Math.floor(this.totalItems / this.itemsPerPage) + 1
      }
    },

    paginationRange() {
      let start = this.currentPage - this.visiblePages / 2 <= 0
        ? 1 : this.currentPage + this.visiblePages / 2 > this.lastPage
          ? this.lowerBound(this.lastPage - this.visiblePages + 1, 1)
          : Math.ceil(this.currentPage - this.visiblePages / 2)
      let range = []
      for (let i = 0; i < this.visiblePages && i < this.lastPage; i++) {
        range.push(start + i)
      }
      return range
    }
  },

  methods: {
    pageChanged(pageNum) {
      if (pageNum <= this.lastPage && pageNum >= 1) this.$emit('page-changed', pageNum)
    },

    activePage(pageNum) {
      return this.currentPage == pageNum ? 'active' : ''
    },
    lowerBound(num, limit) {
      return num >= limit ? num : limit
    }
  }

}
</script>
