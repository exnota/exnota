package data

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"

	lib_block "exnota.com/backend/lib/block"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/daos"
	"github.com/pocketbase/pocketbase/forms"
	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionBlock       = lib_block.CollectionBlock
	BlockFieldType        = "type"
	BlockFieldUser        = "user"
	BlockFieldTitle       = "title"
	BlockFieldFile        = "file"
	BlockFieldAudio       = "audio"
	BlockFieldDestination = "destination"
	BlockFieldExternal    = "external"
)

type BlockType string

const (
	BlockTypeVoiceNote BlockType = "voice-note"
	BlockTypeTextNote  BlockType = "text-note"
)

type Block interface {
	Record() *models.Record

	Id() string
	Title() *string
	Type() BlockType
	User() string
	Destination() string
	External() (*External, error)
	// Not all block types have files, but having this method on the root
	// interface makes it easier to work with blocks in a generic way, e.g.
	// creating immutability rules.
	File() string

	SetTitle(string)
	SetExternalUrl(string) error
	SetExternalExportStatus(ExportStatus) error

	ValidateAndSubmit(txDao *daos.Dao) error
}

func LoadBlock(r *models.Record, app core.App) (Block, error) {
	blockType := BlockType(r.GetString(BlockFieldType))
	switch blockType {
	case BlockTypeVoiceNote:
		return LoadVoiceNoteBlock(r, app)
	case BlockTypeTextNote:
		return LoadTextNoteBlock(r, app)
	}
	return nil, fmt.Errorf("unknown block type %s", blockType)
}

func LoadBlockFromModel(m models.Model, app core.App) (Block, error) {
	castedRecord, ok := m.(*models.Record)
	if !ok {
		return nil, errors.New("not a record")
	}
	return LoadBlock(castedRecord, app)
}

// ----------------------------
// Block base
// ----------------------------

type block struct {
	record *models.Record
	app    core.App
}

func (b *block) Record() *models.Record {
	return b.record
}

func (b *block) Id() string {
	return b.record.Id
}

func (b *block) Title() *string {
	title := b.record.GetString(BlockFieldTitle)
	if title == "" {
		return nil
	}
	return &title
}

func (b *block) Type() BlockType {
	return BlockType(b.record.GetString(BlockFieldType))
}

func (b *block) User() string {
	return b.record.GetString(BlockFieldUser)
}

func (b *block) Destination() string {
	return b.record.GetString(BlockFieldDestination)
}

type External struct {
	Url          string       `json:"url,omitempty"`
	ExportStatus ExportStatus `json:"export_status,omitempty" validate:"omitempty,oneof=complete in-progress error"`
}

type ExportStatus string

const (
	// If modifying this, update the validate tag in External struct.
	ExportStatusComplete   ExportStatus = "complete"
	ExportStatusInProgress ExportStatus = "in-progress"
	ExportStatusError      ExportStatus = "error"
)

func (b *block) External() (*External, error) {
	// Detect if nil.
	//
	// Cannot simply use UnmarshalJSONField because if the field is nil, it will
	// throw an error even though nil is a valid value.
	raw := b.record.Get(BlockFieldExternal).(types.JsonRaw)
	val, err := raw.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return nil, nil
	}

	// Unmarshall
	var external External
	err = b.record.UnmarshalJSONField(BlockFieldExternal, &external)
	if err != nil {
		return nil, err
	}
	return &external, err
}

func (b *block) File() string {
	return b.record.GetString(BlockFieldFile)
}

func (b *block) SetTitle(title string) {
	b.record.Set(BlockFieldTitle, title)
}

func (b *block) SetExternalUrl(url string) error {
	// Update 'external' field
	external, err := b.External()
	if err != nil {
		return err
	}
	if external == nil {
		external = &External{}
	}
	external.Url = url

	// Validate
	err = validate.Struct(external)
	if err != nil {
		return err
	}

	// Save
	configBytes, err := json.Marshal(external)
	if err != nil {
		slog.Error("Error marshalling block external field", "err", err, "id", b.Id())
		return err
	}
	b.record.Set(BlockFieldExternal, string(configBytes))
	return nil
}

func (b *block) SetExternalExportStatus(status ExportStatus) error {
	// Update 'external' field
	external, err := b.External()
	if err != nil {
		return err
	}
	if external == nil {
		external = &External{}
	}
	external.ExportStatus = status

	// Validate
	err = validate.Struct(external)
	if err != nil {
		return err
	}

	// Save
	configBytes, err := json.Marshal(external)
	if err != nil {
		slog.Error("Error marshalling block external field", "err", err, "id", b.Id())
		return err
	}
	b.record.Set(BlockFieldExternal, string(configBytes))
	return nil
}

func (b *block) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(b.app, b.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}

// ----------------------------
// Voice note block
// ----------------------------

type VoiceNoteBlock interface {
	Block

	Audio() (*AudioField, error)
	SetTranscription([]string) error
}

type voiceNoteBlock struct {
	block
}

func LoadVoiceNoteBlock(r *models.Record, app core.App) (VoiceNoteBlock, error) {
	blockType := r.GetString(BlockFieldType)
	if blockType != string(BlockTypeVoiceNote) {
		return nil, errors.New("not a voice note block")
	}
	var b VoiceNoteBlock = &voiceNoteBlock{
		block: block{
			record: r,
			app:    app,
		},
	}
	return b, nil
}

type AudioField struct {
	Transcription []string `json:"transcription"`
}

func (b *voiceNoteBlock) Audio() (*AudioField, error) {
	// Detect if nil.
	//
	// Cannot simply use UnmarshalJSONField because if the field is nil, it will
	// throw an error even though nil is a valid value.
	raw := b.record.Get(BlockFieldAudio).(types.JsonRaw)
	val, err := raw.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return nil, nil
	}

	// Unmarshall
	var field AudioField
	err = b.record.UnmarshalJSONField(BlockFieldAudio, &field)
	if err != nil {
		return nil, err
	}
	return &field, err
}

func (b *voiceNoteBlock) SetTranscription(transcription []string) error {
	rawField := b.record.Get(BlockFieldAudio).(types.JsonRaw)
	val, err := rawField.Value()
	if err != nil {
		return err
	}

	var field AudioField
	if val == nil {
		field = AudioField{}
	} else {
		err = b.record.UnmarshalJSONField(BlockFieldAudio, &field)
		if err != nil {
			return err
		}
	}

	field.Transcription = transcription
	b.record.Set(BlockFieldAudio, field)

	if b.Title() == nil && len(transcription) > 0 {
		b.SetTitle(transcription[0])
	}

	return nil
}

// ----------------------------
// Text note block
// ----------------------------

type TextNoteBlock interface {
	Block
}

type textNoteBlock struct {
	block
}

func LoadTextNoteBlock(r *models.Record, app core.App) (TextNoteBlock, error) {
	blockType := r.GetString(BlockFieldType)
	if blockType != string(BlockTypeTextNote) {
		return nil, errors.New("not a text note block")
	}
	var b TextNoteBlock = &textNoteBlock{
		block: block{
			record: r,
			app:    app,
		},
	}
	return b, nil
}
