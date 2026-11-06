package at.identit.gdpd.reminder;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * gdpd reminders (docs/GDPD_TAEGLICH_CHARAKTER.md 6.3): Android v2 plugin, singleton "GdpdReminder".
 * Method names are snake_case so GDScript calls them as written. GDScript side: scripts/notifier.gd.
 */
public class GdpdReminder extends GodotPlugin {
	private static final String POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS";
	private static final int REQUEST_CODE = 4711;

	public GdpdReminder(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "GdpdReminder";
	}

	private Context ctx() {
		Activity a = getActivity();
		return a == null ? null : a.getApplicationContext();
	}

	/** Stores the alarm (wall-clock fields, month 1..12) and sets it. False if the time is in the past. */
	@UsedByGodot
	public boolean schedule(int id, int year, int month, int day, int hour, int minute, String title, String text,
			String icon_path, int day_key) {
		Context c = ctx();
		if (c == null) {
			return false;
		}
		Planned p = new Planned(id, year, month, day, hour, minute, title, text, icon_path, day_key);
		if (p.millis() <= System.currentTimeMillis()) {
			return false;
		}
		Store.put(c, p);
		Alarms.set(c, p);
		ReminderReceiver.ensureChannel(c);
		Log.i(Store.TAG, "scheduled " + id + " at " + year + "-" + month + "-" + day + " " + hour + ":" + minute);
		return true;
	}

	@UsedByGodot
	public void cancel(int id) {
		Context c = ctx();
		if (c == null) {
			return;
		}
		Alarms.cancel(c, id);
		Store.remove(c, id);
	}

	@UsedByGodot
	public void cancel_all() {
		Context c = ctx();
		if (c == null) {
			return;
		}
		for (Planned p : Store.all(c)) {
			Alarms.cancel(c, p.id);
		}
		Store.clear(c);
	}

	/** The Spieltag is done: alarms of this or an earlier Spieltag are dropped when they fire (stored exactly). */
	@UsedByGodot
	public void mark_done(int day_key) {
		Context c = ctx();
		if (c != null) {
			Store.setDone(c, day_key);
		}
	}

	/** Quiet hours: reminders are only shown between earliest and latest (minutes of the local day). */
	@UsedByGodot
	public void set_window(int earliest, int latest) {
		Context c = ctx();
		if (c != null) {
			Store.setWindow(c, earliest, latest);
		}
	}

	/** Number of stored (not yet fired) reminders – for diagnostics. */
	@UsedByGodot
	public int planned_count() {
		Context c = ctx();
		return c == null ? 0 : Store.all(c).size();
	}

	/** POST_NOTIFICATIONS granted (always true below Android 13, where it is an install-time permission). */
	@UsedByGodot
	public boolean has_permission() {
		Context c = ctx();
		if (c == null) {
			return false;
		}
		return Build.VERSION.SDK_INT < 33 || c.checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
	}

	/**
	 * Asks for POST_NOTIFICATIONS (Android 13+). Returns true if it is already granted (or not needed); otherwise the
	 * system dialog opens and the answer arrives in SceneTree.on_request_permissions_result.
	 */
	@UsedByGodot
	public boolean request_permission() {
		if (has_permission()) {
			return true;
		}
		final Activity a = getActivity();
		if (a == null || Build.VERSION.SDK_INT < 33) {
			return false;
		}
		runOnUiThread(new Runnable() {
			@Override
			public void run() {
				a.requestPermissions(new String[] { POST_NOTIFICATIONS }, REQUEST_CODE);
			}
		});
		return false;
	}

	/** Permission granted and notifications switched on for the app in Android's settings. */
	@UsedByGodot
	public boolean notifications_enabled() {
		Context c = ctx();
		return c != null && ReminderReceiver.mayPost(c);
	}

	/** Opens Android's notification settings of the app (below API 26: the app details page). */
	@UsedByGodot
	public void open_settings() {
		final Activity a = getActivity();
		if (a == null) {
			return;
		}
		runOnUiThread(new Runnable() {
			@Override
			public void run() {
				Intent i;
				if (Build.VERSION.SDK_INT >= 26) {
					i = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS);
					i.putExtra(Settings.EXTRA_APP_PACKAGE, a.getPackageName());
				} else {
					i = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
					i.setData(Uri.fromParts("package", a.getPackageName(), null));
				}
				i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
				try {
					a.startActivity(i);
				} catch (RuntimeException e) {
					Log.w(Store.TAG, "could not open notification settings", e);
				}
			}
		});
	}

	/** The reminder id if the app was opened by tapping a reminder, else -1. Cleared after reading. */
	@UsedByGodot
	public int launch_notification_id() {
		Activity a = getActivity();
		if (a == null || a.getIntent() == null) {
			return -1;
		}
		Intent in = a.getIntent();
		int id = in.getIntExtra(Alarms.EXTRA_ID, -1);
		in.removeExtra(Alarms.EXTRA_ID);
		return id;
	}
}
