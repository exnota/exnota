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

	ValidateAndSubmit(txDao *daos.Dao) error
}

// TODO: Refactor so there's a block struct that implements the Block interface
// and defines common methods, and then have separate structs for each block
// type to implement the specific methods. See block_job.

type VoiceNoteBlock interface {
	Block

	Audio() (*AudioField, error)
	SetTranscription([]string) error
}

func LoadBlock(r *models.Record, app core.App) (Block, error) {
	blockType := BlockType(r.GetString(BlockFieldType))
	switch blockType {
	case BlockTypeVoiceNote:
		var b VoiceNoteBlock = &voiceNoteBlock{
			record: r,
			app:    app,
		}
		return b, nil
	case BlockTypeTextNote:
		var b TextBlock = &textBlock{
			app:    app,
			record: r,
		}
		return b, nil
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

func LoadVoiceNoteBlock(r *models.Record, app core.App) (VoiceNoteBlock, error) {
	blockType := r.GetString(BlockFieldType)
	if blockType != string(BlockTypeVoiceNote) {
		return nil, errors.New("not a voice note block")
	}
	var b VoiceNoteBlock = &voiceNoteBlock{
		app:    app,
		record: r,
	}
	return b, nil
}

type voiceNoteBlock struct {
	app    core.App
	record *models.Record
}

type AudioField struct {
	Transcription []string `json:"transcription"`
}

func (b *voiceNoteBlock) Record() *models.Record {
	return b.record
}

func (b *voiceNoteBlock) Id() string {
	return b.record.Id
}

func (b *voiceNoteBlock) Title() *string {
	title := b.record.GetString(BlockFieldTitle)
	if title == "" {
		return nil
	}
	return &title
}

func (b *voiceNoteBlock) Type() BlockType {
	return BlockType(b.record.GetString(BlockFieldType))
}

func (b *voiceNoteBlock) User() string {
	return b.record.GetString(BlockFieldUser)
}

func (b *voiceNoteBlock) Destination() string {
	return b.record.GetString(BlockFieldDestination)
}

type External struct {
	Url string `json:"url,omitempty"`
}

func (b *voiceNoteBlock) External() (*External, error) {
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

func (b *voiceNoteBlock) File() string {
	return b.record.GetString(BlockFieldFile)
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

func (b *voiceNoteBlock) SetTitle(title string) {
	b.record.Set(BlockFieldTitle, title)
}

func (b *voiceNoteBlock) SetExternalUrl(url string) error {
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

func (b *voiceNoteBlock) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(b.app, b.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}

type TextBlock interface {
	Block
}

type textBlock struct {
	app    core.App
	record *models.Record
}

func (t *textBlock) Record() *models.Record {
	return t.record
}

func (t *textBlock) Id() string {
	return t.record.Id
}

func (t *textBlock) Title() *string {
	title := t.record.GetString(BlockFieldTitle)
	if title == "" {
		return nil
	}
	return &title
}

func (t *textBlock) Type() BlockType {
	return BlockType(t.record.GetString(BlockFieldType))
}

func (t *textBlock) User() string {
	return t.record.GetString(BlockFieldUser)
}

func (t *textBlock) Destination() string {
	return t.record.GetString(BlockFieldDestination)
}

func (t *textBlock) File() string {
	return t.record.GetString(BlockFieldFile)
}

func (t *textBlock) SetTitle(title string) {
	t.record.Set(BlockFieldTitle, title)
}

// TODO:
func (t *textBlock) SetExternalUrl(url string) error {
	// Update 'external' field
	external, err := t.External()
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
		slog.Error("Error marshalling block external field", "err", err, "id", t.Id())
		return err
	}
	t.record.Set(BlockFieldExternal, string(configBytes))
	return nil
}

func (t *textBlock) External() (*External, error) {
	// Detect if nil.
	//
	// Cannot simply use UnmarshalJSONField because if the field is nil, it will
	// throw an error even though nil is a valid value.
	raw := t.record.Get(BlockFieldExternal).(types.JsonRaw)
	val, err := raw.Value()
	if err != nil {
		return nil, err
	}
	if val == nil {
		return nil, nil
	}

	// Unmarshall
	var external External
	err = t.record.UnmarshalJSONField(BlockFieldExternal, &external)
	if err != nil {
		return nil, err
	}
	return &external, err
}

func (t *textBlock) ValidateAndSubmit(txDao *daos.Dao) error {
	form := forms.NewRecordUpsert(t.app, t.record)
	form.SetDao(txDao)

	// Submit calls validate internally
	return form.Submit()
}
