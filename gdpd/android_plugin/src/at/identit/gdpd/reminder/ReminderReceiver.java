package at.identit.gdpd.reminder;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Build;
import android.util.Log;

/**
 * Alarm → notification. Drops the alarm if its Spieltag is already done (mark_done) or the entry was cancelled.
 */
public class ReminderReceiver extends BroadcastReceiver {
	static final String CHANNEL_ID = "erinnerung";
	private static final String POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS";

	@Override
	public void onReceive(Context context, Intent intent) {
		Context ctx = context.getApplicationContext();
		int id = intent.getIntExtra(Alarms.EXTRA_ID, -1);
		Planned p = Store.get(ctx, id);
		if (p == null) {
			Log.i(Store.TAG, "alarm " + id + " has no stored entry (cancelled), dropped");
			return;
		}
		Store.remove(ctx, id);
		if (p.dayKey <= Store.done(ctx)) {
			Log.i(Store.TAG, "alarm " + id + " for day " + p.dayKey + " already done, dropped");
			return;
		}
		show(ctx, p);
	}

	static boolean mayPost(Context ctx) {
		if (Build.VERSION.SDK_INT >= 33
				&& ctx.checkSelfPermission(POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
			return false;
		}
		NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
		if (nm == null) {
			return false;
		}
		return Build.VERSION.SDK_INT < 24 || nm.areNotificationsEnabled();
	}

	static void ensureChannel(Context ctx) {
		if (Build.VERSION.SDK_INT < 26) {
			return;
		}
		NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
		if (nm == null || nm.getNotificationChannel(CHANNEL_ID) != null) {
			return;
		}
		NotificationChannel ch = new NotificationChannel(CHANNEL_ID, "Erinnerungen",
				NotificationManager.IMPORTANCE_DEFAULT);
		ch.setDescription("Höchstens eine Nachricht am Tag von deinem Charakter.");
		nm.createNotificationChannel(ch);
	}

	private static int smallIcon(Context ctx) {
		int res = ctx.getResources().getIdentifier("ic_gdpd_notify", "drawable", ctx.getPackageName());
		if (res == 0) {
			res = ctx.getApplicationInfo().icon;
		}
		return res != 0 ? res : android.R.drawable.ic_dialog_info;
	}

	static void show(Context ctx, Planned p) {
		if (!mayPost(ctx)) {
			Log.i(Store.TAG, "notifications not allowed, reminder " + p.id + " dropped");
			return;
		}
		ensureChannel(ctx);
		NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
		Notification.Builder b;
		if (Build.VERSION.SDK_INT >= 26) {
			b = new Notification.Builder(ctx, CHANNEL_ID);
		} else {
			b = new Notification.Builder(ctx);
			b.setPriority(Notification.PRIORITY_DEFAULT);
		}
		b.setSmallIcon(smallIcon(ctx));
		if (!p.iconPath.isEmpty()) {
			Bitmap face = BitmapFactory.decodeFile(p.iconPath); // null if missing: no large icon
			if (face != null) {
				b.setLargeIcon(face);
			}
		}
		b.setContentTitle(p.title);
		b.setContentText(p.text);
		b.setStyle(new Notification.BigTextStyle().bigText(p.text));
		b.setAutoCancel(true);
		b.setShowWhen(true);
		Intent launch = ctx.getPackageManager().getLaunchIntentForPackage(ctx.getPackageName());
		if (launch != null) {
			launch.putExtra(Alarms.EXTRA_ID, p.id);
			launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			int flags = PendingIntent.FLAG_UPDATE_CURRENT;
			if (Build.VERSION.SDK_INT >= 23) {
				flags |= PendingIntent.FLAG_IMMUTABLE;
			}
			b.setContentIntent(PendingIntent.getActivity(ctx, p.id, launch, flags));
		}
		try {
			nm.notify(p.id, b.build());
			Log.i(Store.TAG, "reminder " + p.id + " shown");
		} catch (SecurityException e) {
			Log.w(Store.TAG, "reminder " + p.id + " not allowed", e);
		}
	}
}
