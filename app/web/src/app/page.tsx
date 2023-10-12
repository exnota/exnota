import { Center, Container, Stack, Title } from "@mantine/core";

export default function Home() {
  return (
    <Container h="100%">
      <Stack justify="center" align="center" h="100%">
        <Title>Exnota</Title>
        <Title order={2} size="h4">
          Quick capture to Notion
        </Title>
      </Stack>
    </Container>
  );
}
