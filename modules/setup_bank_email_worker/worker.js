// Cloudflare Email Worker: target of the Email Routing rule for the bank
// notification address. Forwards every received card notification email to
// the expense tracker's REST API, authenticated with a bearer token.
export default {
  async email(message, env) {
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
