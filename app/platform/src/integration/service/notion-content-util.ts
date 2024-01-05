import { chunkTranscription } from '@exnota/integration/service/truncate'
import { BlockObjectRequest } from '@notionhq/client/build/src/api-endpoints'

function paragraphsForTranscription(noteExport: {
  transcription: string
  transcriptionOpenAi?: string
}): BlockObjectRequest[] {
  if (noteExport.transcriptionOpenAi) {
    return localAndOpenAi(
      noteExport.transcription,
      noteExport.transcriptionOpenAi,
    )
  }
  return localOnly(noteExport.transcription)
}

function localOnly(transcription: string): BlockObjectRequest[] {
  const localChunks = chunkTranscription(transcription, {})
  return localChunks.map((chunk) => {
    return {
      type: 'paragraph',
      paragraph: {
        rich_text: [
          {
            text: {
              content: chunk,
            },
          },
        ],
      },
    }
  })
}

function localAndOpenAi(
  transcription: string,
  transcriptionOpenAi: string,
): BlockObjectRequest[] {
  const localChunks = chunkTranscription(transcription, {})
  const openAiChunks = chunkTranscription(transcriptionOpenAi, {})

  const paragraphs: BlockObjectRequest[] = []
  paragraphs.push({
    type: 'heading_3',
    heading_3: {
      rich_text: [
        {
          type: 'text',
          text: {
            content: 'Local',
          },
        },
      ],
    },
  })
  localChunks.forEach((chunk) => {
    paragraphs.push({
      type: 'paragraph',
      paragraph: {
        rich_text: [
          {
            text: {
              content: chunk,
            },
          },
        ],
      },
    })
  })
  paragraphs.push({
    type: 'heading_3',
    heading_3: {
      rich_text: [
        {
          type: 'text',
          text: {
            content: 'OpenAI',
          },
        },
      ],
    },
  })
  openAiChunks.forEach((chunk) => {
    paragraphs.push({
      type: 'paragraph',
      paragraph: {
        rich_text: [
          {
            text: {
              content: chunk,
            },
          },
        ],
      },
    })
  })
  return paragraphs
}

export { paragraphsForTranscription }
