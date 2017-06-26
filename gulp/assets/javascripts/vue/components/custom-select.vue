<template>
    <div class="custom-select">
        <div v-for="hiddenField in hiddenFields">
            <input type="hidden" :value="hiddenField.value" :name="hiddenFieldId">
        </div>
        <div v-if="hiddenFields == null">
            <input type="hidden" value="" :name="hiddenFieldId">
        </div>
        <div class="dropdown v-select" :class="dropdownClasses">
            <div ref="toggle" @mousedown.prevent="toggleDropdown" class="dropdown-toggle">
    
                <span class="selected-tag" v-for="option in valueAsArray" v-bind:key="option.index">
                    {{ getOptionLabel(option) }}
                    <button v-if="multiple" @click="deselect(option)" type="button" class="close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </span>
    
                <input ref="search" v-model="search" @keydown.delete="maybeDeleteValue" @keyup.esc="onEscape" @keydown.up.prevent="typeAheadUp" @keydown.down.prevent="typeAheadDown" @keydown.enter.prevent="" @keyup.enter.prevent="typeAheadSelect" @blur="onSearchBlur" @focus="onSearchFocus" type="search" class="form-control" :placeholder="searchPlaceholder" :readonly="!searchable" :style="{ width: isValueEmpty ? '100%' : 'auto' }">
    
                <i v-if="!noDrop" ref="openIndicator" role="presentation" class="open-indicator"></i>
    
                <slot name="spinner">
                    <div class="spinner" v-show="mutableLoading">Loading...</div>
                </slot>
            </div>
    
            <transition :name="transition">
                <ul ref="dropdownMenu" v-if="dropdownOpen" class="dropdown-menu" :style="{ 'max-height': maxHeight }">
                    <li v-for="(option, index) in filteredOptions" v-bind:key="index" :class="[{ active: isOptionSelected(option), highlight: index === typeAheadPointer},getLevelForOption(option)]" @mouseover="typeAheadPointer = index">
                        <a @mousedown.prevent="select(option)">
                            {{ getOptionLabel(option) }}
                        </a>
                    </li>
                    <li v-if="!filteredOptions.length" class="no-options">
                        <slot name="no-options">Sorry, no matching options.</slot>
                    </li>
                </ul>
            </transition>
        </div>
    </div>
</template>

<script>
import pointerScroll from '../mixins/pointerScroll'
import typeAheadPointer from '../mixins/typeAheadPointer'
import ajax from '../mixins/ajax'
export default {
    mixins: [pointerScroll, typeAheadPointer, ajax],

    props: {
        value: {
            default: null
        },
        options: {
            type: Array,
            default() {
                return []
            },
        },
        selectedValues: {
            default: null
        },
        customOptions: {
            default: null
        },
        hiddenFieldId: {
            default: null
        },
        hiddenFieldValue: {
            default: null
        },
        multiple: {
            type: Boolean,
            default: true
        },

        /**
         * Sets the max-height property on the dropdown list.
         * @deprecated
         * @type {String}
         */
        maxHeight: {
            type: String,
            default: '400px'
        },

        /**
         * Enable/disable filtering the options.
         * @type {Boolean}
         */
        searchable: {
            type: Boolean,
            default: true
        },

        /**
         * Equivalent to the `placeholder` attribute on an `<input>`.
         * @type {Object}
         */
        placeholder: {
            type: String,
            default: ''
        },

        /**
         * Sets a Vue transition property on the `.dropdown-menu`. vue-select
         * does not include CSS for transitions, you'll need to add them yourself.
         * @type {String}
         */
        transition: {
            type: String,
            default: 'fade'
        },

        /**
         * Enables/disables clearing the search text when an option is selected.
         * @type {Boolean}
         */
        clearSearchOnSelect: {
            type: Boolean,
            default: true
        },

        /**
         * Tells vue-select what key to use when generating option
         * labels when each `option` is an object.
         * @type {String}
         */
        label: {
            type: String,
            default: 'label'
        },

        /**
         * Callback to generate the label text. If {option}
         * is an object, returns option[this.label] by default.
         * @param  {Object || String} option
         * @return {String}
         */
        getOptionLabel: {
            type: Function,
            default(option) {
                if (typeof option === 'object') {
                    if (this.label && option[this.label]) {
                        return option[this.label]
                    }
                }
                return option;
            }
        },

        /**
         * An optional callback function that is called each time the selected
         * value(s) change. When integrating with Vuex, use this callback to trigger
         * an action, rather than using :value.sync to retreive the selected value.
         * @type {Function}
         * @default {null}
         */
        onChange: {
            type: Function,
            default: function (val) {
                this.$emit('input', val)
            }
        },

        /**
         * Enable/disable creating options from searchInput.
         * @type {Boolean}
         */
        taggable: {
            type: Boolean,
            default: false
        },

        /**
         * When true, newly created tags will be added to
         * the options list.
         * @type {Boolean}
         */
        pushTags: {
            type: Boolean,
            default: false
        },

        /**
         * User defined function for adding Options
         * @type {Function}
         */
        createOption: {
            type: Function,
            default(newOption) {
                if (typeof this.mutableOptions[0] === 'object') {
                    newOption = { [this.label]: newOption }
                }
                this.$emit('option:created', newOption)
                return newOption
            }
        },

        /**
         * When false, updating the options will not reset the select value
         * @type {Boolean}
         */
        resetOnOptionsChange: {
            type: Boolean,
            default: false
        },

        /**
         * Disable the dropdown entirely.
         * @type {Boolean}
         */
        noDrop: {
            type: Boolean,
            default: false
        }
    },

    data() {
        return {
            hiddenFields: null,
            search: '',
            open: false,
            mutableValue: null,
            mutableOptions: []
        }
    },

    watch: {
        /**
         * When the value prop changes, update
               * the internal mutableValue.
         * @param  {mixed} val
         * @return {void}
         */
        value(val) {
            this.mutableValue = val
        },

        /**
         * Maybe run the onChange callback.
         * @param  {string|object} val
         * @param  {string|object} old
         * @return {void}
         */
        mutableValue(val, old) {
            if (this.multiple) {
                this.onChange ? this.onChange(val) : null
            } else {
                this.onChange && val !== old ? this.onChange(val) : null
            }
        },

        /**
         * When options change, update
         * the internal mutableOptions.
         * @param  {array} val
         * @return {void}
         */
        options(val) {
            this.mutableOptions = val
        },

        /**
               * Maybe reset the mutableValue
         * when mutableOptions change.
         * @return {[type]} [description]
         */
        mutableOptions() {
            if (!this.taggable && this.resetOnOptionsChange) {
                this.mutableValue = this.multiple ? [] : null
            }
        },

        /**
               * Always reset the mutableValue when
         * the multiple prop changes.
         * @param  {Boolean} val
         * @return {void}
         */
        multiple(val) {
            this.mutableValue = val ? [] : null
        }
    },

    /**
     * Clone props into mutable values,
     * attach any event listeners.
     */
    created() {
        this.mutableValue = this.selectedValues
        this.mutableOptions = this.customOptions.slice(0)
        this.onChange = this.generateHiddenFields
        this.mutableLoading = this.loading

        this.$on('option:created', this.maybePushTag)
    },

    methods: {
        generateHiddenFields(val) {
            this.hiddenFields = val;
            if (val.length == 0) {
                this.hiddenFields = null;
            }
        },

        /**
         * Returns the current level.
         * @param  {Object|String}  option
         * @return {String}        return lvl
         */
        getLevelForOption(option) {
            var level = "level-" + option['level'];
            return level;
        },

        /**
         * Select a given option.
         * @param  {Object|String} option
         * @return {void}
         */
        select(option) {
            if (this.isOptionSelected(option)) {
                this.deselect(option)
            } else {
                if (this.taggable && !this.optionExists(option)) {
                    option = this.createOption(option)
                }

                if (this.multiple && !this.mutableValue) {
                    this.mutableValue = [option]
                } else if (this.multiple) {
                    this.mutableValue.push(option)
                } else {
                    this.mutableValue = option
                }
            }

            this.onAfterSelect(option)
        },

        /**
         * De-select a given option.
         * @param  {Object|String} option
         * @return {void}
         */
        deselect(option) {
            if (this.multiple) {
                let ref = -1
                this.mutableValue.forEach((val) => {
                    if (val === option || typeof val === 'object' && val[this.label] === option[this.label]) {
                        ref = val
                    }
                })
                var index = this.mutableValue.indexOf(ref)
                this.mutableValue.splice(index, 1)
            } else {
                this.mutableValue = null
            }
        },

        /**
         * Called from this.select after each selection.
         * @param  {Object|String} option
         * @return {void}
         */
        onAfterSelect(option) {
            if (!this.multiple) {
                this.open = !this.open
                this.$refs.search.blur()
            }

            if (this.clearSearchOnSelect) {
                this.search = ''
            }
        },

        /**
         * Toggle the visibility of the dropdown menu.
         * @param  {Event} e
         * @return {void}
         */
        toggleDropdown(e) {
            if (e.target === this.$refs.openIndicator || e.target === this.$refs.search || e.target === this.$refs.toggle || e.target === this.$el) {
                if (this.open) {
                    this.$refs.search.blur() // dropdown will close on blur
                } else {
                    this.open = true
                    this.$refs.search.focus()
                }
            }
        },

        /**
         * Check if the given option is currently selected.
         * @param  {Object|String}  option
         * @return {Boolean}        True when selected | False otherwise
         */
        isOptionSelected(option) {
            if (this.multiple && this.mutableValue) {
                let selected = false
                this.mutableValue.forEach(opt => {
                    if (typeof opt === 'object' && opt[this.label] === option[this.label]) {
                        selected = true
                    } else if (typeof opt === 'object' && opt[this.label] === option) {
                        selected = true
                    }
                    else if (opt === option) {
                        selected = true
                    }
                })
                return selected
            }

            return this.mutableValue === option
        },

        /**
         * If there is any text in the search input, remove it.
         * Otherwise, blur the search input to close the dropdown.
         * @return {void}
         */
        onEscape() {
            if (!this.search.length) {
                this.$refs.search.blur()
            } else {
                this.search = ''
            }
        },

        /**
         * Close the dropdown on blur.
         * @emits  {search:blur}
         * @return {void}
         */
        onSearchBlur() {
            this.open = false
            this.$emit('search:blur')
        },

        /**
         * Open the dropdown on focus.
         * @emits  {search:focus}
         * @return {void}
         */
        onSearchFocus() {
            this.open = true
            this.$emit('search:focus')
        },

        /**
         * Delete the value on Delete keypress when there is no
         * text in the search input, & there's tags to delete
         * @return {this.value}
         */
        maybeDeleteValue() {
            if (!this.$refs.search.value.length && this.mutableValue) {
                return this.multiple ? this.mutableValue.pop() : this.mutableValue = null
            }
        },

        /**
         * Determine if an option exists
         * within this.mutableOptions array.
         *
         * @param  {Object || String} option
         * @return {boolean}
         */
        optionExists(option) {
            let exists = false

            this.mutableOptions.forEach(opt => {
                if (typeof opt === 'object' && opt[this.label] === option) {
                    exists = true
                } else if (opt === option) {
                    exists = true
                }
            })

            return exists
        },

        /**
         * If push-tags is true, push the
         * given option to mutableOptions.
         *
         * @param  {Object || String} option
         * @return {void}
         */
        maybePushTag(option) {
            if (this.pushTags) {
                this.mutableOptions.push(option)
            }
        }
    },

    computed: {

        /**
         * Classes to be output on .dropdown
         * @return {Object}
         */
        dropdownClasses() {
            return {
                open: this.dropdownOpen,
                searchable: this.searchable,
                unsearchable: !this.searchable,
                loading: this.mutableLoading
            }
        },

        /**
         * Return the current state of the
         * dropdown menu.
         * @return {Boolean} True if open
         */
        dropdownOpen() {
            return this.noDrop ? false : this.open && !this.mutableLoading
        },

        /**
         * Return the placeholder string if it's set
         * & there is no value selected.
         * @return {String} Placeholder text
         */
        searchPlaceholder() {
            if (this.isValueEmpty && this.placeholder) {
                return this.placeholder;
            }
        },

        /**
         * The currently displayed options, filtered
         * by the search elements value. If tagging
         * true, the search text will be prepended
         * if it doesn't already exist.
         *
         * @return {array}
         */
        filteredOptions() {
            let options = this.mutableOptions.filter((option) => {
                if (typeof option === 'object' && option.hasOwnProperty(this.label)) {
                    return option[this.label].toLowerCase().indexOf(this.search.toLowerCase()) > -1
                } else if (typeof option === 'object' && !option.hasOwnProperty(this.label)) {
                    return console.warn(`[vue-select warn]: Label key "option.${this.label}" does not exist in options object.\nhttp://sagalbot.github.io/vue-select/#ex-labels`)
                }
                return option.toLowerCase().indexOf(this.search.toLowerCase()) > -1
            })
            if (this.taggable && this.search.length && !this.optionExists(this.search)) {
                options.unshift(this.search)
            }
            return options
        },

        /**
         * Check if there aren't any options selected.
         * @return {Boolean}
         */
        isValueEmpty() {
            if (this.mutableValue) {
                if (typeof this.mutableValue === 'object') {
                    return !Object.keys(this.mutableValue).length
                }
                return !this.mutableValue.length
            }

            return true;
        },

        /**
         * Return the current value in array format.
         * @return {Array}
         */
        valueAsArray() {
            if (this.multiple) {
                return this.mutableValue
            } else if (this.mutableValue) {
                return [this.mutableValue]
            }

            return []
        }
    }
}

</script>

<style>

</style>
