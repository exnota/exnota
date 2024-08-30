/**
* This file was @generated using pocketbase-typegen
*/

import type PocketBase from 'pocketbase'
import type { RecordService } from 'pocketbase'

export enum Collections {
	Block = "block",
	BlockJob = "block_job",
	Destination = "destination",
	Feature = "feature",
	Integration = "integration",
	IntegrationBlockNotionMapping = "integration_block_notion_mapping",
	IntegrationDestination = "integration_destination",
	IntegrationNotionObject = "integration_notion_object",
	User = "user",
	UserFeatureSettings = "user_feature_settings",
	Workspace = "workspace",
}

// Alias types for improved usability
export type IsoDateString = string
export type RecordIdString = string
export type HTMLString = string

// System fields
export type BaseSystemFields<T = never> = {
	id: RecordIdString
	created: IsoDateString
	updated: IsoDateString
	collectionId: string
	collectionName: Collections
	expand?: T
}

export type AuthSystemFields<T = never> = {
	email: string
	emailVisibility: boolean
	username: string
	verified: boolean
} & BaseSystemFields<T>

// Record types for each collection

export enum BlockTypeOptions {
	"voice-note" = "voice-note",
	"text-note" = "text-note",
}
export type BlockRecord<Taudio = unknown, Texternal = unknown> = {
	archived?: IsoDateString
	audio?: null | Taudio
	destination?: RecordIdString
	external?: null | Texternal
	file?: string
	title?: string
	type: BlockTypeOptions
	user: RecordIdString
	userCreated: IsoDateString
}

export enum BlockJobTypeOptions {
	"transcription" = "transcription",
	"export" = "export",
}

export enum BlockJobStatusOptions {
	"waiting" = "waiting",
	"running" = "running",
	"error" = "error",
	"complete" = "complete",
}
export type BlockJobRecord<Tconfig = unknown, Tsummary = unknown> = {
	block: RecordIdString
	config?: null | Tconfig
	error_count?: number
	next_run_at: IsoDateString
	status: BlockJobStatusOptions
	summary?: null | Tsummary
	type: BlockJobTypeOptions
	user: RecordIdString
}

export type DestinationRecord<Texternal = unknown> = {
	archived?: IsoDateString
	external?: null | Texternal
	name: string
	user: RecordIdString
	workspace: RecordIdString
	workspace_default?: boolean
}

export enum FeatureProductOptions {
	"exnota" = "exnota",
}
export type FeatureRecord<Tsettings = unknown> = {
	nameID?: string
	product?: FeatureProductOptions
	settings?: null | Tsettings
}

export enum IntegrationTypeOptions {
	"notion" = "notion",
}

export enum IntegrationStatusOptions {
	"connected" = "connected",
	"access-revoked" = "access-revoked",
}
export type IntegrationRecord<Tconfig = unknown> = {
	archived?: IsoDateString
	config?: null | Tconfig
	status: IntegrationStatusOptions
	type: IntegrationTypeOptions
	user: RecordIdString
}

export enum IntegrationBlockNotionMappingBlockTypeOptions {
	"voice-note" = "voice-note",
}
export type IntegrationBlockNotionMappingRecord<Tconfig = unknown> = {
	blockType: IntegrationBlockNotionMappingBlockTypeOptions
	config?: null | Tconfig
	externalBlock: string
	externalDestination: string
	externalUrl: string
	internalBlock: RecordIdString
	internalDestination: RecordIdString
}

export enum IntegrationDestinationExternalRecordTypeOptions {
	"notion" = "notion",
}
export type IntegrationDestinationRecord = {
	destination_id: string
	external_record_id: string
	external_record_type: IntegrationDestinationExternalRecordTypeOptions
	user: RecordIdString
}

export enum IntegrationNotionObjectTypeOptions {
	"page" = "page",
	"database" = "database",
	"block" = "block",
}

export enum IntegrationNotionObjectStatusOptions {
	"connected" = "connected",
	"not-found" = "not-found",
	"archived" = "archived",
	"unknown-error" = "unknown-error",
}
export type IntegrationNotionObjectRecord<Tproperties = unknown> = {
	external_id: string
	last_synced: IsoDateString
	properties?: null | Tproperties
	status: IntegrationNotionObjectStatusOptions
	title?: string
	type: IntegrationNotionObjectTypeOptions
	user: RecordIdString
}

export type UserRecord<TfeatureSettings = unknown> = {
	avatar?: string
	featureSettings?: null | TfeatureSettings
	name?: string
}

export enum UserFeatureSettingsProductOptions {
	"exnota" = "exnota",
}
export type UserFeatureSettingsRecord<Tsettings = unknown, Tuser = unknown> = {
	feature?: RecordIdString
	featureNameID?: string
	product?: UserFeatureSettingsProductOptions
	settings?: null | Tsettings
	user?: null | Tuser
}

export enum WorkspaceTypeOptions {
	"database" = "database",
	"custom" = "custom",
}
export type WorkspaceRecord<Texternal = unknown> = {
	archived?: IsoDateString
	external?: null | Texternal
	icon?: string
	integration?: RecordIdString
	name?: string
	type: WorkspaceTypeOptions
	user: RecordIdString
}

// Response types include system fields and match responses from the PocketBase API
export type BlockResponse<Taudio = unknown, Texternal = unknown, Texpand = unknown> = Required<BlockRecord<Taudio, Texternal>> & BaseSystemFields<Texpand>
export type BlockJobResponse<Tconfig = unknown, Tsummary = unknown, Texpand = unknown> = Required<BlockJobRecord<Tconfig, Tsummary>> & BaseSystemFields<Texpand>
export type DestinationResponse<Texternal = unknown, Texpand = unknown> = Required<DestinationRecord<Texternal>> & BaseSystemFields<Texpand>
export type FeatureResponse<Tsettings = unknown, Texpand = unknown> = Required<FeatureRecord<Tsettings>> & BaseSystemFields<Texpand>
export type IntegrationResponse<Tconfig = unknown, Texpand = unknown> = Required<IntegrationRecord<Tconfig>> & BaseSystemFields<Texpand>
export type IntegrationBlockNotionMappingResponse<Tconfig = unknown, Texpand = unknown> = Required<IntegrationBlockNotionMappingRecord<Tconfig>> & BaseSystemFields<Texpand>
export type IntegrationDestinationResponse<Texpand = unknown> = Required<IntegrationDestinationRecord> & BaseSystemFields<Texpand>
export type IntegrationNotionObjectResponse<Tproperties = unknown, Texpand = unknown> = Required<IntegrationNotionObjectRecord<Tproperties>> & BaseSystemFields<Texpand>
export type UserResponse<TfeatureSettings = unknown, Texpand = unknown> = Required<UserRecord<TfeatureSettings>> & AuthSystemFields<Texpand>
export type UserFeatureSettingsResponse<Tsettings = unknown, Tuser = unknown, Texpand = unknown> = Required<UserFeatureSettingsRecord<Tsettings, Tuser>> & BaseSystemFields<Texpand>
export type WorkspaceResponse<Texternal = unknown, Texpand = unknown> = Required<WorkspaceRecord<Texternal>> & BaseSystemFields<Texpand>

// Types containing all Records and Responses, useful for creating typing helper functions

export type CollectionRecords = {
	block: BlockRecord
	block_job: BlockJobRecord
	destination: DestinationRecord
	feature: FeatureRecord
	integration: IntegrationRecord
	integration_block_notion_mapping: IntegrationBlockNotionMappingRecord
	integration_destination: IntegrationDestinationRecord
	integration_notion_object: IntegrationNotionObjectRecord
	user: UserRecord
	user_feature_settings: UserFeatureSettingsRecord
	workspace: WorkspaceRecord
}

export type CollectionResponses = {
	block: BlockResponse
	block_job: BlockJobResponse
	destination: DestinationResponse
	feature: FeatureResponse
	integration: IntegrationResponse
	integration_block_notion_mapping: IntegrationBlockNotionMappingResponse
	integration_destination: IntegrationDestinationResponse
	integration_notion_object: IntegrationNotionObjectResponse
	user: UserResponse
	user_feature_settings: UserFeatureSettingsResponse
	workspace: WorkspaceResponse
}

// Type for usage with type asserted PocketBase instance
// https://github.com/pocketbase/js-sdk#specify-typescript-definitions

export type TypedPocketBase = PocketBase & {
	collection(idOrName: 'block'): RecordService<BlockResponse>
	collection(idOrName: 'block_job'): RecordService<BlockJobResponse>
	collection(idOrName: 'destination'): RecordService<DestinationResponse>
	collection(idOrName: 'feature'): RecordService<FeatureResponse>
	collection(idOrName: 'integration'): RecordService<IntegrationResponse>
	collection(idOrName: 'integration_block_notion_mapping'): RecordService<IntegrationBlockNotionMappingResponse>
	collection(idOrName: 'integration_destination'): RecordService<IntegrationDestinationResponse>
	collection(idOrName: 'integration_notion_object'): RecordService<IntegrationNotionObjectResponse>
	collection(idOrName: 'user'): RecordService<UserResponse>
	collection(idOrName: 'user_feature_settings'): RecordService<UserFeatureSettingsResponse>
	collection(idOrName: 'workspace'): RecordService<WorkspaceResponse>
}
