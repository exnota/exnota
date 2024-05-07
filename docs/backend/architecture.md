# Architecture

Below are some notes on the architecture we should move to.

They can be deleted, or simplified as a reference, once this project is mostly
migrated to it.

The purpose is to improve DX by:

- Make it obvious where to make changes.
- Decouple domains as much as feasible.
- Single responsibility where feasible.

```
[no domain]
global/api/delete
global/api/auth

[block domain]
service/api/block_auth (special auth rules, e.g. only admin can update certain things)
service/api/block_create (tweak data, useecase specific logic)
service/api/block_update
service/api/block_read
service/api/block_custom_endpoint
service/listeners/block_integration_updates (triggered from other domains, or same domain but decoupledd)
usecase/workspace_updater (usecases that aren't API CRUD operations, called from custom endpoints and event consumers)
repo/block_fetcher|writer
model/block_create  (record validation, cascading (things that ALWAYS happen))
model/block_update
model/block_read
model/block_event_producer (triggers hooks injected from other domains)
model/block

[job domain]
service/cmd/runners
service/event/job_creation_workflow (when triggered from other job, call hook directly. when triggered from block, inject into block domain)


[integration domain]
service/job/exporter (handles jobs)
service/api/custom_endpoints
usecase/notion/api/fetcher
usecase/notion/api/writer
usecase/notion/notion_exporter
usecase/notion/notion_destination_sync

[main]
Hooks order (before events: return errors; after events: swallow errors)
- model crud
- service same domain events
- event producing
Hooks rule
- Before model create/update: Return errors to block the update
- After model create/update: Log and swallow errors to not block other events 
```
