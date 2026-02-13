const CACHE_NAME = 'taskloop-v4';
const ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png',
];

// ---- Cache & Fetch ----
self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (e) => {
  e.respondWith(
    fetch(e.request)
      .then((r) => {
        const clone = r.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(e.request, clone));
        return r;
      })
      .catch(() => caches.match(e.request))
  );
});

// ---- Notifications ----
// Store tasks data for background notification checks
let cachedTasks = [];

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SYNC_TASKS') {
    cachedTasks = event.data.tasks || [];
  }

  if (event.data && event.data.type === 'SHOW_NOTIFICATION') {
    const { title, body, tag } = event.data;
    self.registration.showNotification(title, {
      body,
      icon: 'icon-192.png',
      badge: 'icon-192.png',
      tag: tag || 'taskloop',
      renotify: true,
      vibrate: [200, 100, 200],
      requireInteraction: true,
      actions: [
        { action: 'open', title: 'Oeffnen' },
        { action: 'dismiss', title: 'Spaeter' },
      ],
    });
  }

  if (event.data && event.data.type === 'CHECK_DUE') {
    checkDueTasks();
  }
});

function getNextDue(task) {
  if (!task.lastCompleted) return 0;
  const base = new Date(task.lastCompleted);
  const next = new Date(base);
  switch (task.intervalUnit) {
    case 'days': next.setDate(next.getDate() + task.intervalVal); break;
    case 'weeks': next.setDate(next.getDate() + task.intervalVal * 7); break;
    case 'months': next.setMonth(next.getMonth() + task.intervalVal); break;
    default: next.setDate(next.getDate() + task.intervalVal);
  }
  if (task.reminderTime) {
    const [h, m] = task.reminderTime.split(':').map(Number);
    next.setHours(h, m, 0, 0);
  }
  return next.getTime();
}

function checkDueTasks() {
  const now = Date.now();
  const dueTasks = cachedTasks.filter(t => now >= getNextDue(t));
  if (dueTasks.length > 0) {
    const names = dueTasks.slice(0, 3).map(t => t.name).join(', ');
    const more = dueTasks.length > 3 ? ` und ${dueTasks.length - 3} weitere` : '';
    self.registration.showNotification('TaskLoop', {
      body: `Faellig: ${names}${more}`,
      icon: 'icon-192.png',
      badge: 'icon-192.png',
      tag: 'taskloop-due',
      renotify: true,
      vibrate: [200, 100, 200],
      requireInteraction: true,
      actions: [
        { action: 'open', title: 'Oeffnen' },
        { action: 'dismiss', title: 'Spaeter' },
      ],
    });
  }
}

// Handle notification click — open or focus the app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'dismiss') return;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes('/') && 'focus' in client) {
          return client.focus();
        }
      }
      return self.clients.openWindow('/');
    })
  );
});

// Periodic Background Sync (where supported)
self.addEventListener('periodicsync', (event) => {
  if (event.tag === 'taskloop-check') {
    event.waitUntil(checkDueTasks());
  }
});
