import {
  Card,
  Image,
  Text,
  Badge,
  Button,
  Group,
  CardSection,
} from "@mantine/core";

export function ExnotaTools() {
  return (
    <Card shadow="sm" padding="lg" radius="md" withBorder>
      <Group justify="space-between" mb="xs">
        <Text fw={500}>Exnota Tools</Text>
      </Group>

      <Text size="sm" c="dimmed">
        Free Notion tools, to delete duplicates and more.
      </Text>

      <div>
        <Button
          component="a"
          href="https://tools.exnota.com"
          color="blue"
          variant="light"
          mt="md"
          radius="md"
        >
          Go to Exnota Tools
        </Button>
      </div>
    </Card>
  );
}
