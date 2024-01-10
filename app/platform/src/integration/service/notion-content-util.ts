import { getParagraphs } from '@exnota/integration/service/paragraph'
import { BlockObjectRequest } from '@notionhq/client/build/src/api-endpoints'

async function paragraphsForTranscription(noteExport: {
  transcription: string
  transcriptionOpenAi?: string
}): Promise<BlockObjectRequest[]> {
  if (noteExport.transcriptionOpenAi) {
    return localAndOpenAi(
      noteExport.transcription,
      noteExport.transcriptionOpenAi,
    )
  }
  return localOnly(noteExport.transcription)
}

async function localOnly(transcription: string): Promise<BlockObjectRequest[]> {
  const localChunks = await getParagraphs(transcription)
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

async function localAndOpenAi(
  transcription: string,
  transcriptionOpenAi: string,
): Promise<BlockObjectRequest[]> {
  const localChunks = await getParagraphs(transcription)
  const openAiChunks = await getParagraphs(transcriptionOpenAi)

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
