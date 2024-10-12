"use client";

import { useState } from "react";
import { Container, Group, Image } from "@mantine/core";
import classes from "./HeaderSimple.module.css";

const links = [
  { link: "/about", label: "Features" },
  { link: "/pricing", label: "Pricing" },
  { link: "/learn", label: "Learn" },
  { link: "/community", label: "Community" },
];

export function HeaderSimple() {
  const [active, setActive] = useState(links[0].link);

  return (
    <header className={classes.header}>
      <Container size="md" className={classes.inner}>
        <Group>
          <Image
            src="/images/exnota-128.png"
            alt="Exnota"
            width={32}
            height={32}
          />
          <span className={classes.title}>Exnota</span>
        </Group>
        <Group gap={5} visibleFrom="xs"></Group>
      </Container>
    </header>
  );
}
