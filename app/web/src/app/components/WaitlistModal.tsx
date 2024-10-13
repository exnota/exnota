"use client";

import { useDisclosure } from "@mantine/hooks";
import { Modal, Button, Text } from "@mantine/core";
import MailchimpSubscribe, { EmailFormFields } from "react-mailchimp-subscribe";

const url =
  "https://exnota.us11.list-manage.com/subscribe/post?u=8426b2156993707c321cbaa83&amp;id=6a23a3643b&amp;f_id=001111e1f0";

const CustomForm = ({ status, message, onValidated }: any) => {
  let email: any;
  const submit = () =>
    email &&
    email.value.indexOf("@") > -1 &&
    onValidated({
      EMAIL: email.value,
    });

  return (
    <div
      style={{
        background: "#efefef",
        borderRadius: 2,
        padding: 10,
        display: "inline-block",
      }}
    >
      {status === "sending" && <div style={{ color: "blue" }}>sending...</div>}
      {status === "error" && (
        <div
          style={{ color: "red" }}
          dangerouslySetInnerHTML={{ __html: message }}
        />
      )}
      {status === "success" && (
        <div
          style={{ color: "green" }}
          dangerouslySetInnerHTML={{ __html: message }}
        />
      )}
      <br />
      {status !== "success" && (
        <>
          <input
            style={{ fontSize: "2em", padding: 5 }}
            ref={(node) => (email = node)}
            type="email"
            placeholder="Your email"
          />
          <br />
          <button style={{ fontSize: "2em", padding: 5 }} onClick={submit}>
            Submit
          </button>
        </>
      )}
    </div>
  );
};

export function Demo() {
  const [opened, { open, close }] = useDisclosure(false);

  return (
    <>
      <Modal
        opened={opened}
        onClose={close}
        title="Join Beta Waitlist"
        centered
      >
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
        Join Beta Waitlist
      </Button>
    </>
  );
}
