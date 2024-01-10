import { getParagraphs } from '@exnota/integration/service/paragraph'

describe('getParagraphs', () => {
  describe('Given English text', () => {
    describe('When the text is one very short sentence', () => {
      test('Then it should not chunk to paragraphs', async () => {
        const text = 'This is a short sentence.'
        expect(await getParagraphs(text)).toEqual([text])
      })
    })
    describe('When the text is 5 one-word sentences', () => {
      test('Then it should chunk into 2 paragraphs', async () => {
        const text = 'Here. Are. Five. Full. Sentences.'
        expect(await getParagraphs(text)).toEqual([
          'Here. Are. Five. ',
          'Full. Sentences.',
        ])
      })
    })
    describe('When the text is quite long', () => {
      test('Then it should chunk into paragraphs', async () => {
        const text =
          "Some definitions are broad and encompass unconscious and non-human behavior. Under a broad definition, many animals communicate within their own species and flowers communicate by signaling the location of nectar to bees through their colors and shapes. Other definitions restrict communication to conscious interactions among human beings. Some approaches focus on the use of symbols and signs while others stress the role of understanding, interaction, power, or transmission of ideas. Various characterizations see the communicator's intent to send a message as a central component. In this view, the transmission of information is not sufficient for communication if it happens unintentionally. A version of this view is given by philosopher Paul Grice, who identifies communication with actions that aim to make the recipient aware of the communicator's intention. One question in this regard is whether only successful transmissions of information should be regarded as communication. For example, distortion may interfere with and change the actual message from what was originally intended.] A closely related problem is whether acts of deliberate deception constitute communication." +
          "According to a broad definition by literary critic I. A. Richards, communication happens when one mind acts upon its environment to transmit its own experience to another mind. Another interpretation is given by communication theorists Claude Shannon and Warren Weaver, who characterize communication as a transmission of information brought about by the interaction of several components, such as a source, a message, an encoder, a channel, a decoder, and a receiver. The transmission view is rejected by transactional and constitutive views, which hold that communication is not just about the transmission of information but also about the creation of meaning. Transactional and constitutive perspectives hold that communication shapes the participant's experience by conceptualizing the world and making sense of their environment and themselves. Researchers studying animal and plant communication focus less on meaning-making. Instead, they often define communicative behavior as having other features, such as playing a beneficial role in survival and reproduction, or having an observable response."
        expect(await getParagraphs(text)).toEqual([
          'Some definitions are broad and encompass unconscious and non-human behavior. Under a broad definition, many animals communicate within their own species and flowers communicate by signaling the location of nectar to bees through their colors and shapes. Other definitions restrict communication to conscious interactions among human beings. Some approaches focus on the use of symbols and signs while others stress the role of understanding, interaction, power, or transmission of ideas. ',
          "Various characterizations see the communicator's intent to send a message as a central component. In this view, the transmission of information is not sufficient for communication if it happens unintentionally. A version of this view is given by philosopher Paul Grice, who identifies communication with actions that aim to make the recipient aware of the communicator's intention. One question in this regard is whether only successful transmissions of information should be regarded as communication. ",
          'For example, distortion may interfere with and change the actual message from what was originally intended.] A closely related problem is whether acts of deliberate deception constitute communication.According to a broad definition by literary critic I. A. Richards, communication happens when one mind acts upon its environment to transmit its own experience to another mind. ',
          "Another interpretation is given by communication theorists Claude Shannon and Warren Weaver, who characterize communication as a transmission of information brought about by the interaction of several components, such as a source, a message, an encoder, a channel, a decoder, and a receiver. The transmission view is rejected by transactional and constitutive views, which hold that communication is not just about the transmission of information but also about the creation of meaning. Transactional and constitutive perspectives hold that communication shapes the participant's experience by conceptualizing the world and making sense of their environment and themselves. ",
          'Researchers studying animal and plant communication focus less on meaning-making. Instead, they often define communicative behavior as having other features, such as playing a beneficial role in survival and reproduction, or having an observable response.',
        ])
      })
    })
  })
  describe('Given some Chinese text from Wikipedia', () => {
    test('Then it should chunk into paragraphs', async () => {
      const text =
        '語言溝通是指用口說或是文字來傳達訊息。人類的語言可以定義為由符号（語言學中稱為词位）及语法（定義各詞位之間的關係）組成的系統。语言习得一般主要是在兒童期時出現。大部份的人類語言會使用声音或是手势的組合來表示词位，以便於和其他人溝通。語言多半有些共通的特質，不過也有例外。在一種語言中，可能存在在特定地區使用，和其他語言有部份差異的方言。人工語言（例如世界语）、编程语言不一定會有人類語言中會有的一些共用性質。' +
        '語言有其符號式的特質。Charles Ogden和I.A Richards發展了语义三角（Triangle of Meaning）模型，來解釋符號（字和字之間的關係）、指稱對象（描述的事物）以及意義（有關字和其事物之間的概念）之間的關係[20]。' +
        '語言的性質會受到一些規則的支配。在語言中的規則有語音規則（語言中會使用哪些聲音）、句法規則（詞的拼字以及詞在句子中的順序）、語義規則（單詞的含義）及語用規則（配合上下文得到的含義）。' +
        '單字中的含義可能是字面的，或稱為外延意義（denotative），是和討論主題有關的，也有可能其含義需要考慮上下文以及溝通者之間的關係，稱為是內涵意義（connotative），和溝通者的感受、歷史以及其彼此的權力動態有關[21]。' +
        '世界上的手語（例如美國手語）雖然是以肢體表達，看似和肢體語言類似。可是其中有詞彙、文法以及其他語言中必要的特徵[22][23][24]，也屬於語言溝通。手語中也有非語言的成份，例如速度、強度，以及其動作的大小。例如表示「是」的手語可以用在回答問題，也可以用一個誇飾、動作很大又很慢的「是」，其非語言的意義完全不同。「是」的手語是語言訊息，而其他部份就是非語言的訊息。 '
      expect(await getParagraphs(text)).toEqual([
        '語言溝通是指用口說或是文字來傳達訊息。人類的語言可以定義為由符号（語言學中稱為词位）及语法（定義各詞位之間的關係）組成的系統。语言习得一般主要是在兒童期時出現。大部份的人類語言會使用声音或是手势的組合來表示词位，以便於和其他人溝通。',
        '語言多半有些共通的特質，不過也有例外。在一種語言中，可能存在在特定地區使用，和其他語言有部份差異的方言。人工語言（例如世界语）、编程语言不一定會有人類語言中會有的一些共用性質。語言有其符號式的特質。',
        'Charles Ogden和I.A Richards發展了语义三角（Triangle of Meaning）模型，來解釋符號（字和字之間的關係）、指稱對象（描述的事物）以及意義（有關字和其事物之間的概念）之間的關係[20]。語言的性質會受到一些規則的支配。在語言中的規則有語音規則（語言中會使用哪些聲音）、句法規則（詞的拼字以及詞在句子中的順序）、語義規則（單詞的含義）及語用規則（配合上下文得到的含義）。單字中的含義可能是字面的，或稱為外延意義（denotative），是和討論主題有關的，也有可能其含義需要考慮上下文以及溝通者之間的關係，稱為是內涵意義（connotative），和溝通者的感受、歷史以及其彼此的權力動態有關[21]。',
        '世界上的手語（例如美國手語）雖然是以肢體表達，看似和肢體語言類似。可是其中有詞彙、文法以及其他語言中必要的特徵[22][23][24]，也屬於語言溝通。手語中也有非語言的成份，例如速度、強度，以及其動作的大小。',
        '例如表示「是」的手語可以用在回答問題，也可以用一個誇飾、動作很大又很慢的「是」，其非語言的意義完全不同。「是」的手語是語言訊息，而其他部份就是非語言的訊息。 ',
      ])
    })
  })
})
