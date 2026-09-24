// Vite entrypoint for /schema. Its components and ~2.5k lines of SCSS are useless on
// every other backend page, so they ship here instead of in the application bundle
// (see schema/index.html.erb and show.html.erb, which request it via body_scripts).
import "../stylesheets/schema.scss";
import registerComponents from "../javascripts/register_components";

registerComponents(
	import.meta.glob("../javascripts/schema/**/*.js", {
		eager: true,
		import: "default",
	}),
);
