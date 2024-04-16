package data

import (
	"errors"
	"fmt"

	lib_block "exnota.com/backend/lib/block"
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
)

type BlockType string

const (
	BlockTypeVoiceNote BlockType = "voice-note"
	BlockTypeTextNote  BlockType = "text-note"
)

type Block interface {
	Record() *models.Record

	Id() string
	Type() BlockType
	User() string
	Destination() string
	// Not all block types have files, but having this method on the root
	// interface makes it easier to work with blocks in a generic way, e.g.
	// creating immutability rules.
	File() string

	SetTitle(string)
}

type VoiceNoteBlock interface {
	Block

	SetTranscription([]string) error
}

func NewBlock(r *models.Record) (Block, error) {
	blockType := BlockType(r.GetString(BlockFieldType))
	switch blockType {
	case BlockTypeVoiceNote:
		var b VoiceNoteBlock = &voiceNoteBlock{
			record: r,
		}
		return b, nil
	case BlockTypeTextNote:
		var b TextBlock = &textBlock{
			record: r,
		}
		return b, nil
	}
	return nil, fmt.Errorf("unknown block type %s", blockType)
}

func NewBlockFromModel(m models.Model) (Block, error) {
	castedRecord, ok := m.(*models.Record)
	if !ok {
		return nil, errors.New("not a record")
	}
	return NewBlock(castedRecord)
}

func NewVoiceNoteBlock(r *models.Record) (VoiceNoteBlock, error) {
	blockType := r.GetString(BlockFieldType)
	if blockType != string(BlockTypeVoiceNote) {
		return nil, errors.New("not a voice note block")
	}
	var b VoiceNoteBlock = &voiceNoteBlock{
		record: r,
	}
	return b, nil
}

type voiceNoteBlock struct {
	record *models.Record
}

type audioField struct {
	Transcription []string `json:"transcription"`
}

func (b *voiceNoteBlock) Record() *models.Record {
	return b.record
}

func (b *voiceNoteBlock) Id() string {
	return b.record.Id
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

func (b *voiceNoteBlock) File() string {
	return b.record.GetString(BlockFieldFile)
}

func (b *voiceNoteBlock) SetTitle(title string) {
	b.record.Set(BlockFieldTitle, title)
}

func (b *voiceNoteBlock) SetTranscription(transcription []string) error {
	rawField := b.record.Get(BlockFieldAudio).(types.JsonRaw)
	val, err := rawField.Value()
	if err != nil {
		return err
	}

	var field audioField
	if val == nil {
		field = audioField{}
	} else {
		err = b.record.UnmarshalJSONField(BlockFieldAudio, &field)
		if err != nil {
			return err
		}
	}

	field.Transcription = transcription
	b.record.Set(BlockFieldAudio, field)
	return nil
}

type TextBlock interface {
	Block
}

type textBlock struct {
	record *models.Record
}

func (t *textBlock) Record() *models.Record {
	return t.record
}

func (t *textBlock) Id() string {
	return t.record.Id
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
