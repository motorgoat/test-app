const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

function getNextDue(task) {
  if (!task.lastCompleted) return 0;
  const base = new Date(task.lastCompleted);
  const next = new Date(base);
  switch (task.intervalUnit) {
    case 'hours': next.setHours(next.getHours() + task.intervalVal); break;
    case 'days': next.setDate(next.getDate() + task.intervalVal); break;
    case 'weeks': next.setDate(next.getDate() + task.intervalVal * 7); break;
    case 'months': next.setMonth(next.getMonth() + task.intervalVal); break;
    default: next.setDate(next.getDate() + task.intervalVal);
  }
  if (task.reminderTime && task.intervalUnit !== 'hours') {
    const [h, m] = task.reminderTime.split(':').map(Number);
    next.setHours(h, m, 0, 0);
  }
  return next.getTime();
}

// Runs every minute, checks for due tasks, sends FCM push notifications
exports.checkDueTasks = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async () => {
    const db = admin.database();
    const snap = await db.ref('taskloop').once('value');
    const allData = snap.val();
    if (!allData) return null;

    const now = Date.now();
    const promises = [];

    for (const [code, data] of Object.entries(allData)) {
      if (!data.fcmTokens || !data.tasks) continue;

      const dueTasks = (Array.isArray(data.tasks) ? data.tasks : Object.values(data.tasks))
        .filter(t => now >= getNextDue(t));
      if (dueTasks.length === 0) continue;

      // Don't spam: max once per 15 minutes per sync-code
      if (data.lastPushAt && now - data.lastPushAt < 15 * 60 * 1000) continue;

      const names = dueTasks.slice(0, 3).map(t => t.name).join(', ');
      const more = dueTasks.length > 3 ? ` und ${dueTasks.length - 3} weitere` : '';

      const tokens = Object.values(data.fcmTokens);
      for (const token of tokens) {
        promises.push(
          admin.messaging().send({
            token,
            notification: {
              title: 'TaskLoop',
              body: `Faellig: ${names}${more}`,
            },
            webpush: {
              notification: {
                icon: '/icon-192.png',
                badge: '/icon-192.png',
                vibrate: [200, 100, 200],
                requireInteraction: true,
              },
            },
          }).catch(err => {
            // Remove invalid tokens
            if (err.code === 'messaging/invalid-registration-token' ||
                err.code === 'messaging/registration-token-not-registered') {
              const entry = Object.entries(data.fcmTokens).find(([, v]) => v === token);
              if (entry) {
                return db.ref(`taskloop/${code}/fcmTokens/${entry[0]}`).remove();
              }
            }
          })
        );
      }
      promises.push(db.ref(`taskloop/${code}/lastPushAt`).set(now));
    }

    await Promise.all(promises);
    return null;
  });
