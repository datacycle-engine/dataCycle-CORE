import GeoKeyFigure from "../components/geo_key_figure";

export default function () {
	DataCycle.registerAddCallback(
		".geo-key-figure-button",
		"geo-key-figure",
		(e) => new GeoKeyFigure(e),
	);
}
