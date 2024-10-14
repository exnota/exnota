import { ExnotaTools } from "@exnota-web/app/components/ExnotaTools";
import { HeaderSimple } from "@exnota-web/app/components/HeaderSimple";
import { HeroTitle } from "@exnota-web/app/components/HeroTitle";
import { Container, SimpleGrid, Space, Text } from "@mantine/core";

export default function Home(props: any) {
  return (
    <Container my="md">
      <HeaderSimple />
      {/* <SimpleGrid cols={{ base: 1, sm: 1 }} spacing="xl"> */}
      {/* <Skeleton radius="md" animate={false} height="500" /> */}
      <HeroTitle />
      <Space h="150" />
      <ExnotaTools />
      <Space h="50" />
      <Text size="sm">
        By Matt Schultz (<a href="https://matt.fyi">matt.fyi</a> /{" "}
        <a href="https://x.com/mattjustfyi">@mattjustfyi</a>)
      </Text>
      {/* <Grid gutter="md">
          <GridCol>
          </GridCol>
        </Grid> */}
      {/* </SimpleGrid> */}
    </Container>
  );
}
