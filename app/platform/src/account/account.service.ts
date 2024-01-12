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

  private tokens: { userId: string; token: string }[] = []

  // eslint-disable-next-line require-await
  async findOne(username: string): Promise<User | undefined> {
    return this.users.find((user) => user.username === username)
  }

  // eslint-disable-next-line require-await
  async findOneByEmail(email: string): Promise<User | undefined> {
    return this.users.find((user) => user.email === email)
  }

  saveToken(req: { userId: string; token: string }): void {
    if (
      !this.users.find(
        // TS things req.userId will be a string, but in runtime it's a number
        (user) => user.userId.toString() === req.userId.toString(),
      )
    ) {
      throw new Error('User not found')
    }
    this.tokens.push(req)
  }
}
