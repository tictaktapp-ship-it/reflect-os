// Shared branded email layout for Reflect OS transactional emails.
// Usage:
//   import { buildEmail, type EmailSection } from "../_shared/email-layout.ts";

const APP_URL = "https://app.reflect-os.com";

export interface EmailSection {
  heading?: string;
  html: string;
}

export interface EmailOptions {
  title: string;
  preheader?: string;
  sections: EmailSection[];
  ctaLabel?: string;
  ctaUrl?: string;
  /** Defaults to APP_URL/settings/privacy */
  unsubscribeUrl?: string;
}

export function buildEmail(opts: EmailOptions): string {
  const {
    title,
    preheader = "",
    sections,
    ctaLabel,
    ctaUrl,
    unsubscribeUrl = `${APP_URL}/settings/privacy`,
  } = opts;

  const sectionsHtml = sections
    .map((s) => {
      const headingHtml = s.heading
        ? `<p style="margin:0 0 8px 0;font-size:12px;text-transform:uppercase;letter-spacing:0.5px;color:#666;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">${s.heading}</p>`
        : "";
      return `${headingHtml}<div style="background:#f5f5f7;border-radius:8px;padding:16px;margin-bottom:16px;">${s.html}</div>`;
    })
    .join("\n");

  const ctaHtml =
    ctaLabel && ctaUrl
      ? `<p style="text-align:center;margin:24px 0 8px 0;">
           <a href="${ctaUrl}"
              style="background:#0D7377;color:#ffffff;padding:12px 24px;border-radius:6px;text-decoration:none;display:inline-block;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:14px;font-weight:600;"
           >${ctaLabel}</a>
         </p>`
      : "";

  const preheaderHtml = preheader
    ? `<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">${preheader}&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;</div>`
    : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1.0" />
  <meta http-equiv="X-UA-Compatible" content="IE=edge" />
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background:#f0f0f0;">
${preheaderHtml}
<table width="100%" cellpadding="0" cellspacing="0" border="0" role="presentation" style="background:#f0f0f0;">
  <tr>
    <td align="center" style="padding:24px 16px;">

      <table width="600" cellpadding="0" cellspacing="0" border="0" role="presentation"
             style="max-width:600px;width:100%;background:#ffffff;border-radius:8px;overflow:hidden;">

        <!-- ── Brand teal top strip ── -->
        <tr>
          <td style="height:4px;background:#0D7377;font-size:0;line-height:0;">&nbsp;</td>
        </tr>

        <!-- ── Header: logo + app name ── -->
        <tr>
          <td style="padding:24px;">
            <table cellpadding="0" cellspacing="0" border="0" role="presentation">
              <tr>
                <td style="vertical-align:middle;padding-right:12px;">
                  <img src="${APP_URL}/icons/Icon-192.png"
                       width="48" height="48" alt="Reflect OS"
                       style="display:block;border-radius:8px;" />
                </td>
                <td style="vertical-align:middle;">
                  <span style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
                               font-size:20px;font-weight:700;color:#0D7377;">Reflect OS</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- ── Body ── -->
        <tr>
          <td style="padding:0 24px 24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
                     font-size:14px;line-height:1.6;color:#1a1a2e;">
            ${sectionsHtml}
            ${ctaHtml}
          </td>
        </tr>

        <!-- ── Footer ── -->
        <tr>
          <td style="padding:16px 24px;border-top:1px solid #e8e8e8;
                     font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
                     font-size:12px;color:#999;text-align:center;line-height:1.6;">
            <p style="margin:0 0 4px 0;">
              <a href="${unsubscribeUrl}" style="color:#999;text-decoration:underline;">Manage notification preferences</a>
            </p>
            <p style="margin:0;">
              Sent by Reflect OS &middot;
              <a href="${APP_URL}" style="color:#999;text-decoration:none;">app.reflect-os.com</a>
            </p>
          </td>
        </tr>

      </table>
    </td>
  </tr>
</table>
</body>
</html>`;
}
