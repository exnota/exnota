package data

import (
	"errors"
	"fmt"

	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	CollectionBlock       = "block"
	BlockFieldType        = "type"
	BlockFieldUser        = "user"
	BlockFieldTitle       = "title"
	BlockFieldFile        = "file"
	BlockFieldAudio       = "audio"
	BlockFieldDestination = "destination"
)

type BlockType string

const (
	BlockTypeAudio BlockType = "audio"
)

type Block interface {
	Id() string
	Type() BlockType
	User() string
	Destination() string
	File() string

	SetTitle(string)
}

type AudioBlock interface {
	Block
	SetTranscription([]string) error
}

func NewBlock(r *models.Record) (Block, error) {
	blockType := BlockType(r.GetString(BlockFieldType))
	switch blockType {
	case BlockTypeAudio:
		var b AudioBlock = &audioBlock{
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

func NewAudioBlock(r *models.Record) (AudioBlock, error) {
	blockType := r.GetString(BlockFieldType)
	if blockType != string(BlockTypeAudio) {
		return nil, errors.New("not an audio block")
	}
	var b AudioBlock = &audioBlock{
		record: r,
	}
	return b, nil
}

type audioBlock struct {
	record *models.Record
}

type audioField struct {
	Transcription []string `json:"transcription"`
}

func (b *audioBlock) Id() string {
	return b.record.Id
}

func (b *audioBlock) Type() BlockType {
	return BlockType(b.record.GetString(BlockFieldType))
}

func (b *audioBlock) User() string {
	return b.record.GetString(BlockFieldUser)
}

func (b *audioBlock) Destination() string {
	return b.record.GetString(BlockFieldDestination)
}

func (b *audioBlock) File() string {
	return b.record.GetString(BlockFieldFile)
}

func (b *audioBlock) SetTitle(title string) {
	b.record.Set(BlockFieldTitle, title)
}

func (b *audioBlock) SetTranscription(transcription []string) error {
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
