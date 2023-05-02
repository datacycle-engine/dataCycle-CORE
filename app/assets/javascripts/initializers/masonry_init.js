import MasonryGrid from "./../components/masonry_grid";

export default function () {
	DataCycle.initNewElements(".grid:not(.dcjs-grid)", (e) => new MasonryGrid(e));
}
