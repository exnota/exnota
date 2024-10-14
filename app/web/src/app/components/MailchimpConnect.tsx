import Script from "next/script";

export function MailchimpConnect() {
  return (
    <Script
      id="mcjs"
      dangerouslySetInnerHTML={{
        __html: `!function(c,h,i,m,p){m=c.createElement(h),p=c.getElementsByTagName(h)[0],m.async=1,m.src=i,p.parentNode.insertBefore(m,p)}(document,"script","https://chimpstatic.com/mcjs-connected/js/users/8426b2156993707c321cbaa83/d4c2c4ff93b737d47f5e37b1b.js");`,
      }}
    />
  );
}
