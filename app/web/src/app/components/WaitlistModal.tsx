"use client";

import { useDisclosure } from "@mantine/hooks";
import { Modal, Button, Text, TextInput, Alert } from "@mantine/core";
import MailchimpSubscribe, { EmailFormFields } from "react-mailchimp-subscribe";
import {
  IconCheck,
  IconLoader,
  IconMail,
  IconPhoto,
} from "@tabler/icons-react";

const url =
  "https://exnota.us11.list-manage.com/subscribe/post?u=8426b2156993707c321cbaa83&amp;id=6a23a3643b&amp;f_id=001111e1f0";

const CustomForm = ({ status, message, onValidated }: any) => {
  let email: any;
  let sending = status === "sending";
  const submit = () =>
    email &&
    email.value.indexOf("@") > -1 &&
    onValidated({
      EMAIL: email.value,
    });
  const icon = <IconCheck />;

  return (
    <div>
      {status === "success" && (
        <Alert variant="light" color="lime" title="You're in!" icon={icon}>
          Please confirm in the email we've sent.
        </Alert>
      )}
      {status !== "success" && (
        <>
          <Text>
            Join the waitlist to be updated on the beta availability and launch
            of Exnota.
          </Text>
          <TextInput
            mt="md"
            rightSectionPointerEvents="none"
            label="Your email"
            placeholder="name@email.com"
            ref={(node) => (email = node)}
            type="email"
            error={status === "error" ? message : null}
          />
          <br />
          <Button variant="filled" onClick={submit} loading={sending}>
            Join Waitlist
          </Button>
        </>
      )}
    </div>
  );
};

export function WaitlistModal() {
  const [opened, { open, close }] = useDisclosure(false);

  return (
    <>
      <Modal opened={opened} onClose={close} title="Join Waitlist" centered>
        <MailchimpSubscribe
          url={url}
          render={({ subscribe, status, message }) => (
            <CustomForm
              status={status}
              message={message}
              onValidated={(formData: EmailFormFields) => subscribe(formData)}
            />
          )}
        />
      </Modal>

      <Button
        onClick={open}
        size="xl"
        // className={classes.control}
        variant="gradient"
        gradient={{ from: "blue", to: "cyan" }}
      >
        Join Waitlist
      </Button>
    </>
  );
}
