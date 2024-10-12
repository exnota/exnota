"use client";

import { useEffect } from "react";

export function MailchimpConnect() {
  useEffect(() => {
    // @ts-expect-error
    !(function (c, h, i, m, p) {
      // @ts-expect-error
      (m = c.createElement(h)),
        // @ts-expect-error
        (p = c.getElementsByTagName(h)[0]),
        // @ts-expect-error
        (m.async = 1),
        // @ts-expect-error
        (m.src = i),
        // @ts-expect-error
        p.parentNode.insertBefore(m, p);
    })(
      document,
      "script",
      "https://chimpstatic.com/mcjs-connected/js/users/8426b2156993707c321cbaa83/d4c2c4ff93b737d47f5e37b1b.js"
    );
  }, []);

  return <script id="mcjs"></script>;
}
