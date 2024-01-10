async function getParagraphs(text: string): Promise<string[]> {
  const sentences = await getSentences(text)
  const paragraphs = await chunkParagraph(sentences)
  return paragraphs.map((paragraph) => paragraph.join(''))
}

async function chunkParagraph(sentences: string[]): Promise<string[][]> {
  if (sentences.length <= 4) {
    return [sentences]
  }
  if (sentences.length <= 6) {
    return [sentences.slice(0, 3), sentences.slice(3)]
  }
  return [sentences.slice(0, 4), ...(await chunkParagraph(sentences.slice(4)))]
}

async function getSentences(text: string): Promise<string[]> {
  const language = await getLanguage(text)
  const segment = new Intl.Segmenter(language, { granularity: 'sentence' })
  const iterator = segment.segment(text)[Symbol.iterator]()
  return Array.from(iterator).map((segment) => segment.segment)
}

async function getLanguage(text: string): Promise<string> {
  // Import is dynamic only due to 'franc' only support ESM, while this project
  // is compiled using commonjs, as per tsconfig.
  const franc = await import('franc')
  return franc.franc(text)
}

export { getParagraphs, getLanguage, getSentences }
