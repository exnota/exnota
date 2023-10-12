import {
  Center,
  Container,
  Stack,
  Title,
  Text,
  Box,
  Anchor,
  Space,
} from "@mantine/core";
import Link from "next/link";

export default function Home() {
  return (
    <Container h="100%">
      <Stack justify="center" align="center" h="100%">
        <Stack gap="xs" align="center">
          <Title>Exnota</Title>
          <Title order={2} size="h4">
            Quick capture to Notion
          </Title>
        </Stack>
        <Space h="xl" />
        <Text c="gray">
          By <Anchor href="https://matt.fyi">matt.fyi</Anchor>&nbsp;•&nbsp;
          <Anchor href="https://twitter.com/mattjustfyi">@mattjustfyi</Anchor>
        </Text>
      </Stack>
    </Container>
  );
}
