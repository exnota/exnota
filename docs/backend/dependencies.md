# Dependencies

## Update risks

### go-notion

- Integration Notion Object collection: Structs received from requests, e.g. Properties, are marshalled directly to the `properties` field. If go-notion changes the shape of the structs, then the logic to fetch data from inside this may need to be forked for pre- vs post-updated data. See:
  - `integration/usecase/notion/sync_notion_destination.go`
  - `integration/data/integration_notion_object_repo_writer.go`
