import { Injectable, Logger } from '@nestjs/common';
// import path from 'path';
import { promisify } from 'util';

// TODO: Some options here
// - https://stackoverflow.com/questions/71819037/esm-import-a-node-addon
// - See near end: https://dev.to/wolfejw86/the-commonjs-vs-es-modules-war-is-taxing-for-us-regular-folks-out-here-one-way-to-interop-55e
// - https://github.com/microsoft/TypeScript/issues/43329
// - https://stackoverflow.com/questions/74830166/unable-to-import-esm-module-in-nestjs
// Bonus
// - https://medium.com/jspoint/a-simple-guide-to-load-c-c-code-into-node-js-javascript-applications-3fcccf54fd32

//// @ts-expect-error need to add type defs
// import { whisper } from '../../lib/whisper/whisper-addon';

// Doesn't seem to work
// const dynamicImport = async (packageName: string) =>
//   new Function(`return import('${packageName}')`)();

// eslint-disable-next-line @typescript-eslint/no-var-requires
const path = require('path');

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { whisper } = require(
  path.join(__dirname, '../../lib/whisper/whisper-addon.node'),
);

@Injectable()
export class TranscriptionService {
  private readonly logger = new Logger(TranscriptionService.name);

  async transcribe(): Promise<string> {
    // const whisperPackage = await dynamicImport(
    //   '../../lib/whisper/whisper-addon.node',
    // );
    // const { whisper } = whisperPackage;

    const whisperAsync = promisify(whisper);
    const whisperParams = {
      language: 'en',
      model: path.join(__dirname, '../../lib/whisper/ggml-tiny.en.bin'),
      fname_inp: path.join(__dirname, '../../lib/whisper/jfk.wav'),
    };

    this.logger.log('whisperParams', whisperParams);

    let result;
    try {
      result = await whisperAsync(whisperParams);
    } catch (e) {
      this.logger.error(`Error calling whisper`, e);
    }
    this.logger.log(`Result from whisper: ${result}`);
    return Promise.resolve('transcription3');
  }
}
