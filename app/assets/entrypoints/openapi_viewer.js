// Vite entrypoint for the OpenAPI (Swagger UI) viewer. The self-initializing
// boot logic lives in the shared module so it stays in sync with the viewer
// implementation (#50192); the entrypoint only needs to import it.
import "../javascripts/openapi_viewer_boot";
