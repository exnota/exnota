import { HeaderSimple } from "@exnota-web/app/components/HeaderSimple";
import { HeroTitle } from "@exnota-web/app/components/HeroTitle";
import { Container, SimpleGrid } from "@mantine/core";

export default function Home(props: any) {
  return (
    <Container my="md">
      <HeaderSimple />
      <SimpleGrid cols={{ base: 1, sm: 1 }} spacing="md">
        {/* <Skeleton radius="md" animate={false} height="500" /> */}
        <HeroTitle />
        {/* <Grid gutter="md">
          <GridCol>
          </GridCol>
        </Grid> */}
      </SimpleGrid>
    </Container>
  );
}
