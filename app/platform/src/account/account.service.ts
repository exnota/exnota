import { Injectable } from '@nestjs/common'

// This should be a real class/interface representing a user entity
export type User = any

@Injectable()
export class AccountService {
  private readonly users = [
    {
      userId: 1,
      username: 'john',
      email: 'john@example.com',
      password: 'changeme',
    },
    {
      userId: 2,
      username: 'maria',
      email: 'maria@example.com',
      password: 'guess',
    },
  ]

  private tokens: { userId: string; token: string }[] = [
    {
      token: '5aa3b88e9670f4850876f7edeb0aa8fba4284bfd7507e4da2728f6851d6b33c6',
      userId: '1',
    },
    {
      userId: '2',
      token: 'a-token',
    },
  ]

  find(username: string): User | undefined {
    return this.users.find((user) => user.username === username)
  }

  findByEmail(email: string): User | undefined {
    return this.users.find((user) => user.email === email)
  }

  findByToken(token: string): any {
    // TODO: In future, ignore expired tokens
    const userId = this.tokens.find((t) => t.token === token)?.userId
    if (!userId) {
      return null
    }
    const user =
      this.users.find((user) => user.userId.toString() === userId) ?? null
    if (!user) {
      return null
    }
    const { password, ...result } = user
    return result
  }

  saveToken(req: { userId: string; token: string }): void {
    if (
      !this.users.find(
        // TS thinks req.userId will be a string, but in runtime it's a number.
        (user) => user.userId.toString() === req.userId.toString(),
      )
    ) {
      throw new Error('User not found')
    }
    this.tokens.push(req)
  }
}
