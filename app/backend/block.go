package main

import (
	"errors"

	"github.com/pocketbase/pocketbase/models"
	"github.com/pocketbase/pocketbase/tools/types"
)

type Block interface {
	SetTitle(string)
}

type AudioBlock interface {
	Block
	SetTranscription([]string) error
}

func NewBlock(r *models.Record) (Block, error) {
	blockType := r.GetString(typeKey)
	switch blockType {
	case "audio":
		var b AudioBlock = &audioBlock{
			record: r,
		}
		return b, nil
	}
	return nil, errors.New("unknown block type")
}

func NewAudioBlock(r *models.Record) (AudioBlock, error) {
	blockType := r.GetString(typeKey)
	if blockType != "audio" {
		return nil, errors.New("not an audio block")
	}
	var b AudioBlock = &audioBlock{
		record: r,
	}
	return b, nil
}

const (
	typeKey  = "type"
	userKey  = "user"
	titleKey = "title"
	fileKey  = "file"
	audioKey = "audio"
)

type audioBlock struct {
	record *models.Record
}

type audioField struct {
	Transcription []string `json:"transcription"`
}

func (b *audioBlock) SetTitle(title string) {
	b.record.Set(titleKey, title)
}

func (b *audioBlock) SetTranscription(transcription []string) error {
	rawField := b.record.Get(audioKey).(types.JsonRaw)
	val, err := rawField.Value()
	if err != nil {
		return err
	}

	var field audioField
	if val == nil {
		field = audioField{}
	} else {
		err = b.record.UnmarshalJSONField(audioKey, &field)
		if err != nil {
			return err
		}
	}

	field.Transcription = transcription
	b.record.Set(audioKey, field)
	return nil
}
