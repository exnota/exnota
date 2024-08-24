package api

// Use '/api' for consistent base paths and '/api/exnota' to avoid
// collisions with future PocketBase URLs.

// Block
const (
	SearchWorkspaceDestinations = "/api/exnota/workspace/search-destinations"
)

// Integration
const (
	GetSuggestedDestinations    = "/api/exnota/integration/notion/get-suggested-destinations"
	NotionMobileCodeRequestPath = "/api/exnota/integration/notion/mobile-code-request-path"
	NotionMobileRedirectPath    = "/api/exnota/integration/notion/mobile-code-redirect"
	IntegrationVerifyAccess     = "/api/exnota/integration/verify-access"
	SyncIntegrationDestinations = "/api/exnota/integration/sync-destinations"
)
