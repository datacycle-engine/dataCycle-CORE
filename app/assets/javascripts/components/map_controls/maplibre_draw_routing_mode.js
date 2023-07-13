import PixelmapRoutingService from "./pixelmap_routing_service";
import CalloutHelpers from "../../helpers/callout_helpers";

const MaplibreDrawRoutingMode = {};

MaplibreDrawRoutingMode.onSetup = function (opts) {
	const featureId = opts?.featureId;
	const mode = opts?.mode?.replace(/^draw_line_string_/, "");

	let line;
	let currentVertexPosition;

	if (featureId) {
		line = this.getFeature(featureId);

		if (!line) {
			throw new Error("Could not find a feature with the provided featureId");
		}

		let from = opts.from;
		if (
			from &&
			from.type === "Feature" &&
			from.geometry &&
			from.geometry.type === "Point"
		) {
			from = from.geometry;
		}
		if (
			from &&
			from.type === "Point" &&
			from.coordinates &&
			from.coordinates.length === 2
		) {
			from = from.coordinates;
		}
		if (!from || !Array.isArray(from)) {
			throw new Error(
				"Please use the `from` property to indicate which point to continue the line from",
			);
		}
		const lastCoord = line.coordinates.length - 1;

		if (
			line.coordinates[lastCoord][0] === from[0] &&
			line.coordinates[lastCoord][1] === from[1]
		) {
			currentVertexPosition = lastCoord + 1;
			line.addCoordinate(currentVertexPosition, ...line.coordinates[lastCoord]);
		} else {
			throw new Error(
				"`from` should match the point at either the start or the end of the provided LineString",
			);
		}
	} else {
		line = this.newFeature({
			type: "Feature",
			properties: {},
			geometry: {
				type: "LineString",
				coordinates: [],
			},
		});
		currentVertexPosition = 0;
		this.addFeature(line);
	}

	this.clearSelectedFeatures();
	this.updateUIClasses({ mouse: "add" });
	this.setActionableState({
		trash: true,
	});

	return {
		mode,
		line,
		currentVertexPosition,
	};
};

MaplibreDrawRoutingMode.clickAnywhere = async function (state, e) {
	const coordinates = state.line.coordinates[state.currentVertexPosition - 1];
	if (
		state.currentVertexPosition > 0 &&
		e.lngLat?.lng === coordinates[0] &&
		e.lngLat?.lat === coordinates[1]
	) {
		return this.changeMode("simple_select", { featureIds: [state.line.id] });
	}

	this.updateUIClasses({ mouse: "add" });

	state.line.updateCoordinate(
		state.currentVertexPosition,
		e.lngLat.lng,
		e.lngLat.lat,
	);

	const routingOptions = {
		...this.drawConfig?.routingOptions,
		costing: state.mode,
		locations: state.line.coordinates.slice(-2).map((v) => {
			return {
				lon: v[0],
				lat: v[1],
			};
		}),
	};

	state.loading = true;
	let points = [[e.lngLat.lat, e.lngLat.lng]];
	if (routingOptions.locations.length >= 2) {
		const newPoints = await PixelmapRoutingService.route(routingOptions).catch(
			this.renderError.bind(this),
		);

		if (newPoints) points = newPoints;
		else this.renderError();
	}

	if (state.currentVertexPosition > 0) state.currentVertexPosition--; // update current position in first iteration

	for (const point of points) {
		state.currentVertexPosition++;
		state.line.updateCoordinate(
			state.currentVertexPosition,
			point[1],
			point[0],
		);
	}

	state.loading = false;
};

MaplibreDrawRoutingMode.renderError = function () {
	I18n.t("frontend.map.routing.error").then((text) =>
		CalloutHelpers.show(text, "alert"),
	);
};

MaplibreDrawRoutingMode.clickOnVertex = function (state) {
	return this.changeMode("simple_select", { featureIds: [state.line.id] });
};

MaplibreDrawRoutingMode.onMouseMove = function (state, e) {
	if (!state.loading)
		state.line.updateCoordinate(
			state.currentVertexPosition,
			e.lngLat.lng,
			e.lngLat.lat,
		);

	if (e.featureTarget?.properties?.meta === "vertex")
		this.updateUIClasses({ mouse: "pointer" });
};

MaplibreDrawRoutingMode.onTap = MaplibreDrawRoutingMode.onClick = function (
	state,
	e,
) {
	if (e.featureTarget?.properties?.meta === "vertex")
		return this.clickOnVertex(state, e);

	this.clickAnywhere(state, e);
};

MaplibreDrawRoutingMode.onKeyUp = function (state, e) {
	if (e.keyCode === 13) {
		this.changeMode("simple_select", { featureIds: [state.line.id] });
	} else if (e.keyCode === 27) {
		this.deleteFeature([state.line.id], { silent: true });
		this.changeMode("simple_select");
	}
};

MaplibreDrawRoutingMode.sleep = function (ms) {
	return new Promise((resolve) => setTimeout(resolve, ms));
};

MaplibreDrawRoutingMode.onStop = function (state) {
	// check to see if we've deleted this feature
	if (this.getFeature(state.line.id) === undefined) return;

	//remove last added coordinate
	state.line.removeCoordinate(`${state.currentVertexPosition}`);

	if (state.line.isValid()) {
		this.map.fire("draw.create", {
			features: [state.line.toGeoJSON()],
		});
	} else {
		this.deleteFeature([state.line.id], { silent: true });
		this.changeMode("simple_select", {}, { silent: true });
	}
};

MaplibreDrawRoutingMode.onTrash = function (state) {
	this.deleteFeature([state.line.id], { silent: true });
	this.changeMode("simple_select");
};

MaplibreDrawRoutingMode.toDisplayFeatures = function (state, geojson, display) {
	const isActiveLine = geojson.properties.id === state.line.id;
	geojson.properties.active = isActiveLine ? "true" : "false";
	if (!isActiveLine) return display(geojson);
	// Only render the line if it has at least one real coordinate
	if (geojson.geometry.coordinates.length < 2) return;

	geojson.properties.meta = "feature";

	display(
		this.createVertex(
			state.line.id,
			geojson.geometry.coordinates[geojson.geometry.coordinates.length - 2],
			`${geojson.geometry.coordinates.length - 2}`,
			false,
		),
	);

	display(geojson);
};

MaplibreDrawRoutingMode.createVertex = function (
	parentId,
	coordinates,
	path,
	selected,
) {
	return {
		type: "Feature",
		properties: {
			meta: "vertex",
			parent: parentId,
			coord_path: path,
			active: selected ? "true" : "false",
		},
		geometry: {
			type: "Point",
			coordinates,
		},
	};
};

export default MaplibreDrawRoutingMode;
