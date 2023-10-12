import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Exnota: Quick capture to Notion',
  description: 'Exnota: Quick capture to Notion',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
