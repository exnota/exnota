import { SetMetadata } from '@nestjs/common'

export const IS_PUBLIC_KEY = 'isPublic'

// This annotation flags that a controller should not use the default
// authentication guard.

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true)
