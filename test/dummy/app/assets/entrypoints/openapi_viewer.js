// Host projects pick the gem's entrypoints up through the config/vite.json glob, which
// keys them as ../../vendor/gems/data-cycle-core/… — the path dc_vite_entry_name falls
// back to. Here the gem is at ../../ instead, so that key never matches and the dummy
// names the entrypoint itself to get the plain `entrypoints/openapi_viewer.js` key.
import "../../../../../app/assets/javascripts/openapi_viewer_boot";
