package at.identit.gdpd.reminder;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Boot, app update, time-zone or clock change: alarms are gone (or point to the wrong instant), so set them again
 * from the stored wall-clock fields. Past entries and entries of done Spieltage are dropped. The quiet-hours check
 * happens when an alarm fires (ReminderReceiver.allowedNow), because inexact alarms can fire late.
 */
public class RestoreReceiver extends BroadcastReceiver {
	@Override
	public void onReceive(Context context, Intent intent) {
		Context ctx = context.getApplicationContext();
		long now = System.currentTimeMillis();
		int done = Store.done(ctx);
		int restored = 0;
		for (Planned p : Store.all(ctx)) {
			if (p.millis() <= now || (p.dayKey != ReminderReceiver.TEST_KEY && p.dayKey <= done)) {
				Alarms.cancel(ctx, p.id);
				Store.remove(ctx, p.id);
				continue;
			}
			Alarms.set(ctx, p);
			restored++;
		}
		Log.i(Store.TAG, "restored " + restored + " reminder(s) after " + intent.getAction());
	}
}
