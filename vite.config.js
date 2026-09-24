import RubyPlugin from "vite-plugin-ruby";
import { resolve } from "path";
import gzipPlugin from "rollup-plugin-gzip";

export default ({ mode }) => {
	return {
		resolve: {
			alias: {
				"@core_assets": resolve(__dirname, "app/assets"),
			},
			// host projects import these assets by relative path, so a nested
			// node_modules here would otherwise give plugins their own jQuery.
			dedupe: ["jquery"],
		},
		server: {
			// The HMR socket is the one vite request Rails' asset proxy does not relabel to
			// VITE_RUBY_HOST, so vite sees the browser's own host -- a netbird peer FQDN such
			// as open-data-cycle-manuel.pxlpnt.net where the stack publishes no ports, which
			// vite answers with "host not allowed" until it is listed here.
			allowedHosts: (process.env.VITE_ALLOWED_HOSTS ?? "").split(",").filter(Boolean),
		},
		build: {
			chunkSizeWarningLimit: 5000,
			brotliSize: false,
		},
		plugins: [RubyPlugin(), ...(mode === "development" ? [] : [gzipPlugin()])],
	};
};
