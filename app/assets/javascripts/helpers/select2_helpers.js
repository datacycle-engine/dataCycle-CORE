export default {
	addselectionTitleAttributeOption: ($) => {
		// Extend defaults
		//
		var Defaults = $.fn.select2.amd.require("select2/defaults");

		$.extend(Defaults.defaults, {
			selectionTitleAttribute: true,
		});

		// SingleSelection
		//
		var SingleSelection = $.fn.select2.amd.require("select2/selection/single");

		var _updateSingleSelection = SingleSelection.prototype.update;

		SingleSelection.prototype.update = function (data) {
			// invoke parent method
			_updateSingleSelection.apply(
				this,
				Array.prototype.slice.apply(arguments),
			);

			var selectionTitleAttribute = this.options.get("selectionTitleAttribute");

			if (selectionTitleAttribute === false) {
				var $rendered = this.$selection.find(".select2-selection__rendered");
				$rendered.removeAttr("title");
			}
		};

		// MultipleSelection
		//
		var MultipleSelection = $.fn.select2.amd.require(
			"select2/selection/multiple",
		);

		var _updateMultipleSelection = MultipleSelection.prototype.update;

		MultipleSelection.prototype.update = function (data) {
			// invoke parent method
			_updateMultipleSelection.apply(
				this,
				Array.prototype.slice.apply(arguments),
			);

			var selectionTitleAttribute = this.options.get("selectionTitleAttribute");

			if (selectionTitleAttribute === false) {
				var $rendered = this.$selection.find(".select2-selection__rendered");
				$rendered.find(".select2-selection__choice").removeAttr("title");
				this.$selection
					.find(".select2-selection__choice__remove")
					.removeAttr("title");
			}
		};
	},
};
