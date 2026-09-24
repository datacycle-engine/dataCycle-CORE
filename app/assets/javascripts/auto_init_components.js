import registerComponents from "./register_components";

const autoInitComponents = import.meta.glob("./auto_init_components/**/*.js", {
	eager: true,
	import: "default",
});

export default function () {
	registerComponents(autoInitComponents);
}
