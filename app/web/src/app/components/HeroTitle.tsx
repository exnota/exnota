import { Text, Group, Stack, Image, Grid, GridCol } from "@mantine/core";
import classes from "./HeroTitle.module.css";
import { Demo } from "@exnota-web/app/components/WaitlistModal";

export function HeroTitle() {
  return (
    <Grid gutter={{ base: "lg" }}>
      <GridCol span={{ base: 12, md: 6 }} order={{ base: 1, md: 0 }}>
        <Stack gap="sm">
          <h1 className={classes.title}>Quick capture to Notion</h1>

          <Text className={classes.description} color="dimmed">
            Voice memos, bookmarks, clippings, and more.
          </Text>

          <Text className={classes.description} color="dimmed">
            iOS and Android.
          </Text>

          <Group className={classes.controls}>
            <Demo />
            {/* <Button
              size="xl"
              className={classes.control}
              variant="gradient"
              gradient={{ from: "blue", to: "cyan" }}
            >
              Join Beta Waitlist
            </Button> */}
          </Group>
        </Stack>
      </GridCol>
      <GridCol span={{ base: 12, md: 6 }}>
        <Image
          src="/images/exnota.gif"
          alt="Recording a voice note in Exnota will send a transcription to Notion."
          fit="contain"
          // width="64"
          // height="64"
        />
      </GridCol>
    </Grid>
  );
}
