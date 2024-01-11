# NestJs

## Interceptors and dependency injection

_(No example of this in the codebase yet.)_

According to [the docs](https://docs.nestjs.com/interceptors#aspect-interception), _"Interceptors, like controllers, providers, guards, and so on, can inject dependencies through their constructor."_

For a build-in interceptor, like `FileInterceptor`, this might require [creating a mixin](https://github.com/nestjs/nest/issues/2513). There are no official NestJS docs on how to do this. Mixins seem like [a typescript concept](https://www.typescriptlang.org/docs/handbook/mixins.html).

I did find [one article](https://wanago.io/2021/12/13/api-nestjs-mixin-pattern/) solving this exact problem for `FileInterceptor`, which I [saved a backup of](https://www.notion.so/makiworld/Nestjs-mixin-pattern-for-interceptors-fileinterceptor-42b41bb169cf4520972a61189850f1d7).

There's also [a SO comment](https://stackoverflow.com/a/51755845) about mixins.