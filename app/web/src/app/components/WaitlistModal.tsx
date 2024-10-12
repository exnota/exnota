"use client";

import { useDisclosure } from "@mantine/hooks";
import { Modal, Button, Text } from "@mantine/core";

export function Demo() {
  const [opened, { open, close }] = useDisclosure(false);

  return (
    <>
      <Modal opened={opened} onClose={close} title="Authentication" centered>
        <Text>Hi</Text>
      </Modal>

      <Button
        // onClick={open}
        size="xl"
        // className={classes.control}
        variant="gradient"
        gradient={{ from: "blue", to: "cyan" }}
      >
        Join Beta Waitlist
      </Button>
    </>
  );
}
