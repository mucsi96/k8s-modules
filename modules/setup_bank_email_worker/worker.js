// Cloudflare Email Worker: target of the Email Routing rule for the bank
// notification address. Forwards received card notification emails to the
// expense tracker's REST API, authenticated with a bearer token.
//
// Email Routing rule matchers can only match the "to" field, so filtering by
// sender and subject happens here: anything that isn't a card notification
// from an allowed bank sender is dropped without forwarding.
export default {
  async email(message, env) {
    const allowedSenders = env.ALLOWED_SENDERS.split(",").map((sender) =>
      sender.trim().toLowerCase()
    );
    const from = message.from.toLowerCase();
    const subject = message.headers.get("subject") ?? "";

    if (
      !allowedSenders.includes(from) ||
      !subject.toLowerCase().startsWith(env.SUBJECT_PREFIX.toLowerCase())
    ) {
      // Returning without forwarding drops the message. No setReject: bouncing
      // spam sent to a published address only generates backscatter.
      return;
    }

    const raw = await new Response(message.raw).text();

    const response = await fetch(env.TARGET_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.API_TOKEN}`,
      },
      body: JSON.stringify({
        from: message.from,
        to: message.to,
        subject: message.headers.get("subject") ?? "",
        raw,
      }),
    });

    if (!response.ok) {
      // Failing the delivery makes the sending mail server retry later, so a
      // temporarily unreachable expense tracker doesn't silently drop the
      // notification.
      throw new Error(`Expense tracker responded with HTTP ${response.status}`);
    }
  },
};
