"use client";

import { useDisclosure } from "@mantine/hooks";
import { Modal, Button, Text } from "@mantine/core";
import MailchimpSubscribe from "react-mailchimp-subscribe";

const url =
  "https://exnota.us11.list-manage.com/subscribe/post?u=8426b2156993707c321cbaa83&amp;id=6a23a3643b&amp;f_id=001111e1f0";

export function Demo() {
  const [opened, { open, close }] = useDisclosure(false);

  return (
    <>
      <Modal opened={opened} onClose={close} title="Authentication" centered>
        <MailchimpSubscribe url={url} />
      </Modal>

      <Button
        onClick={open}
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
