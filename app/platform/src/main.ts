import { NestFactory } from '@nestjs/core'
import { NoteModule } from '@exnota/note/note.module'
import { test as shellTest, mkdir } from 'shelljs'
import { PATH_UPLOAD_AUDIO } from './settings'

async function bootstrap() {
  if (!shellTest('-d', PATH_UPLOAD_AUDIO)) {
    // This was in Dockerfile. It worked locally in dev containers and directly
    // in Docker Desktop but on render.com it wasn't created. It didn't error
    // when building the image but when running the container /tmp was empty.
    // The only difference between environments I noticed was that when using
    // both local approaches there were files already in /tmp. For dev
    // containers a bunch of stuff, for Docker Desktop a single v8 related file
    // or folder.
    //
    // Now that I think about it, I did read somewhere that /tmp may be cleared
    // on restart. That might be what was happening: render.com restarting the
    // container as part of its deploy process. /var/tmp might also be
    // appropriate.
    mkdir('-p', [PATH_UPLOAD_AUDIO])
  }

  const app = await NestFactory.create(NoteModule)
  await app.listen(3000)
}
bootstrap()
