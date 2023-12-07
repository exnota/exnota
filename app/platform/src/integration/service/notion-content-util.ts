import { chunkTranscription } from '@exnota/integration/service/truncate'
import { BlockObjectRequest } from '@notionhq/client/build/src/api-endpoints'

function paragraphsForTranscription(
  transcription: string,
): BlockObjectRequest[] {
  const chunks = chunkTranscription(transcription, {})
  return chunks.map((chunk) => {
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

export { paragraphsForTranscription }
