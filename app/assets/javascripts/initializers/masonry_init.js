import MasonryGrid from "./../components/masonry_grid";

export default function () {
	DataCycle.registerAddCallback(".grid", "grid", (e) => new MasonryGrid(e));
}
