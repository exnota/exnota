import { HeaderSimple } from "@exnota-web/app/components/HeaderSimple";
import { HeroTitle } from "@exnota-web/app/components/HeroTitle";
import { LeadGrid } from "@exnota-web/app/components/LeadGrid";
import {
  Center,
  Container,
  Stack,
  Title,
  Text,
  Box,
  Anchor,
  Space,
  rem,
  SimpleGrid,
  Skeleton,
  Grid,
  GridCol,
  Image,
} from "@mantine/core";

import Link from "next/link";

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
