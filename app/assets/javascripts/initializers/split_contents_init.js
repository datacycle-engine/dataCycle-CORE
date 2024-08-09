import SplitView from "./../components/split_view";
import SimpleFields from "../components/SimpleFields";

export default function () {
	DataCycle.registerAddCallback(
		".flex-box .detail-content .properties",
		"split-view",
		(e) => new SplitView(e),
	);
	new SimpleFields();

	// SPLIT CONTENT
	if ($(".split-content").length) {
		$(".split-content").on("mouseover", function () {
			$(".split-content").addClass("nothover");
			$(this).removeClass("nothover");
		});
		$(".has-changes").on("click", function () {
			$(".split-content .properties .selected").removeClass("selected");
			current = $(this).data("label");
			newelem = $(".split-content").last().find(`[data-label='${current}']`);
			newelem.addClass("selected");
			$(".split-content")
				.last()
				.animate(
					{
						scrollTop:
							newelem.offset().top -
							$(".split-content").last().offset().top +
							$(".split-content").last().scrollTop() -
							150,
					},
					500,
				);
			$(".split-content")
				.first()
				.animate(
					{
						scrollTop:
							$(this).offset().top -
							$(".split-content").first().offset().top +
							$(".split-content").first().scrollTop() -
							150,
					},
					500,
				);
		});
	}
}
