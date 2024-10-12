import type { Metadata } from "next";
// Import styles of packages that you've installed.
// All packages except `@mantine/hooks` require styles imports
import "@mantine/core/styles.css";

import { MantineProvider, ColorSchemeScript } from "@mantine/core";
import { useEffect } from "react";
import { MailchimpConnect } from "@exnota-web/app/components/MailchimpConnect";

export const metadata: Metadata = {
  title: "Exnota: Quick capture to Notion",
  description: "Exnota: Quick capture to Notion",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <ColorSchemeScript />
        <MailchimpConnect />
      </head>
      <body>
        <MantineProvider>{children}</MantineProvider>
      </body>
    </html>
  );
}
