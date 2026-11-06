package at.identit.gdpd.reminder;

import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/**
 * Inexact alarms only (no SCHEDULE_EXACT_ALARM permission, 5.7/5.8): setAndAllowWhileIdle from API 23, set below.
 */
final class Alarms {
	static final String EXTRA_ID = "gdpd_reminder_id";

	private Alarms() {}

	private static PendingIntent pending(Context ctx, int id) {
		Intent i = new Intent(ctx, ReminderReceiver.class);
		i.setAction("at.identit.gdpd.reminder.FIRE." + id);
		i.putExtra(EXTRA_ID, id);
		int flags = PendingIntent.FLAG_UPDATE_CURRENT;
		if (Build.VERSION.SDK_INT >= 23) {
			flags |= PendingIntent.FLAG_IMMUTABLE;
		}
		return PendingIntent.getBroadcast(ctx, id, i, flags);
	}

	static void set(Context ctx, Planned p) {
		AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
		if (am == null) {
			return;
		}
		long at = p.millis();
		if (Build.VERSION.SDK_INT >= 23) {
			am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending(ctx, p.id));
		} else {
			am.set(AlarmManager.RTC_WAKEUP, at, pending(ctx, p.id));
		}
	}

	static void cancel(Context ctx, int id) {
		AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
		if (am != null) {
			am.cancel(pending(ctx, id));
		}
		NotificationManager nm = (NotificationManager) ctx.getSystemService(Context.NOTIFICATION_SERVICE);
		if (nm != null) {
			nm.cancel(id);
		}
	}
}
