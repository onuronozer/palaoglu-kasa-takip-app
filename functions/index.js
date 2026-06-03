const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger, setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 3 });

const db = getFirestore();
const reminderWindowMinutes = 15;

exports.onAnnouncementCreated = onDocumentCreated(
  "duyurular/{announcementId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }

    await sendPushToActiveUsers({
      title: textValue(data.baslik, "Palaoğlu Yönetim"),
      body: textValue(data.mesaj, "Yeni duyuru var."),
      data: {
        type: "announcement",
        announcementId: event.params.announcementId,
      },
    });
  },
);

exports.sendDailyCiroReminder = onSchedule(
  {
    schedule: "0 12 * * *",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    await sendPushToActiveUsers({
      title: "Günlük ciro hatırlatması",
      body: "Bugünün cirosunu girmeyi unutma.",
      data: { type: "daily_kiraathane_reminder" },
    });
  },
);

exports.sendDueReminders = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const now = new Date();
    const snapshot = await db
      .collection("hatirlatmalar")
      .where("active", "==", true)
      .get();

    for (const doc of snapshot.docs) {
      const reminder = doc.data();
      const scheduledAt = dateValue(reminder.scheduledAt);
      if (!scheduledAt) {
        continue;
      }

      const pushKey = reminderPushKey(reminder, scheduledAt, now);
      if (!pushKey || reminder.lastPushKey === pushKey) {
        continue;
      }

      if (!shouldSendReminder(reminder, scheduledAt, now)) {
        continue;
      }

      await sendPushToActiveUsers({
        title: textValue(reminder.baslik, "Yapılacak iş"),
        body: textValue(reminder.not, "Yapılacak iş zamanı geldi."),
        data: {
          type: "reminder",
          reminderId: doc.id,
        },
      });

      await doc.ref.update({
        lastPushKey: pushKey,
        lastPushAt: Timestamp.now(),
      });
    }
  },
);

async function sendPushToActiveUsers({ title, body, data }) {
  const tokenDocs = await activeTokenDocs();
  if (tokenDocs.length === 0) {
    logger.info("No active FCM tokens.");
    return;
  }

  const messaging = getMessaging();
  for (const chunk of chunks(tokenDocs, 500)) {
    const tokens = chunk.map((doc) => doc.get("token")).filter(Boolean);
    if (tokens.length === 0) {
      continue;
    }

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringData(data),
      android: {
        priority: "high",
        notification: {
          channelId: "palaoglu_reminders",
          sound: "default",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    await deactivateInvalidTokens(chunk, response);
    logger.info("Push sent.", {
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  }
}

async function activeTokenDocs() {
  const tokenSnapshot = await db
    .collection("fcm_tokens")
    .where("active", "==", true)
    .get();
  if (tokenSnapshot.empty) {
    return [];
  }

  const uidSet = new Set();
  for (const doc of tokenSnapshot.docs) {
    const uid = doc.get("uid");
    if (uid) {
      uidSet.add(uid);
    }
  }

  const activeUids = new Set();
  for (const uid of uidSet) {
    const userDoc = await db.collection("users").doc(uid).get();
    const user = userDoc.data();
    if (user?.active === true) {
      activeUids.add(uid);
    }
  }

  return tokenSnapshot.docs.filter((doc) => activeUids.has(doc.get("uid")));
}

async function deactivateInvalidTokens(tokenDocs, response) {
  const batch = db.batch();
  let hasUpdates = false;

  response.responses.forEach((item, index) => {
    if (item.success) {
      return;
    }
    const code = item.error?.code ?? "";
    if (
      code.includes("registration-token-not-registered") ||
      code.includes("invalid-registration-token")
    ) {
      batch.update(tokenDocs[index].ref, {
        active: false,
        updatedAt: Timestamp.now(),
      });
      hasUpdates = true;
    }
  });

  if (hasUpdates) {
    await batch.commit();
  }
}

function shouldSendReminder(reminder, scheduledAt, now) {
  if (reminder.repeat === "monthly") {
    return shouldSendMonthlyReminder(scheduledAt, now);
  }
  const diffMs = now.getTime() - scheduledAt.getTime();
  return diffMs >= 0 && diffMs <= reminderWindowMinutes * 60 * 1000;
}

function shouldSendMonthlyReminder(scheduledAt, now) {
  const due = istanbulParts(scheduledAt);
  const current = istanbulParts(now);
  if (due.day !== current.day) {
    return false;
  }
  const dueMinutes = due.hour * 60 + due.minute;
  const currentMinutes = current.hour * 60 + current.minute;
  const diff = currentMinutes - dueMinutes;
  return diff >= 0 && diff <= reminderWindowMinutes;
}

function reminderPushKey(reminder, scheduledAt, now) {
  if (reminder.repeat === "monthly") {
    const current = istanbulParts(now);
    return `monthly:${current.year}-${String(current.month).padStart(2, "0")}`;
  }
  return `once:${scheduledAt.toISOString()}`;
}

function istanbulParts(date) {
  const formatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Istanbul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const parts = {};
  for (const part of formatter.formatToParts(date)) {
    if (part.type !== "literal") {
      parts[part.type] = Number(part.value);
    }
  }
  return parts;
}

function dateValue(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function textValue(value, fallback) {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

function stringData(data) {
  const result = {};
  for (const [key, value] of Object.entries(data ?? {})) {
    result[key] = String(value);
  }
  return result;
}

function chunks(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}
