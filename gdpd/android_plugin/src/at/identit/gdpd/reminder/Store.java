package at.identit.gdpd.reminder;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** The planned reminders (as JSON) and the last done Spieltag, in SharedPreferences, so receivers can read them. */
final class Store {
	static final String TAG = "GdpdReminder";
	private static final String PREFS = "gdpd_reminder";
	private static final String KEY_PLANNED = "planned";
	private static final String KEY_DONE = "done_key";
	private static final String KEY_EARLIEST = "window_earliest";
	private static final String KEY_LATEST = "window_latest";
	static final int DEFAULT_EARLIEST = 8 * 60;
	static final int DEFAULT_LATEST = 21 * 60 + 30;

	private Store() {}

	private static SharedPreferences prefs(Context ctx) {
		return ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
	}

	static synchronized List<Planned> all(Context ctx) {
		List<Planned> out = new ArrayList<>();
		String raw = prefs(ctx).getString(KEY_PLANNED, "[]");
		try {
			JSONArray arr = new JSONArray(raw);
			for (int i = 0; i < arr.length(); i++) {
				JSONObject o = arr.optJSONObject(i);
				if (o != null) {
					out.add(Planned.fromJson(o));
				}
			}
		} catch (JSONException e) {
			Log.w(TAG, "stored plan unreadable, dropped", e);
		}
		return out;
	}

	private static void write(Context ctx, List<Planned> list) {
		JSONArray arr = new JSONArray();
		for (Planned p : list) {
			try {
				arr.put(p.toJson());
			} catch (JSONException e) {
				Log.w(TAG, "could not store reminder " + p.id, e);
			}
		}
		prefs(ctx).edit().putString(KEY_PLANNED, arr.toString()).apply();
	}

	static synchronized Planned get(Context ctx, int id) {
		for (Planned p : all(ctx)) {
			if (p.id == id) {
				return p;
			}
		}
		return null;
	}

	static synchronized void put(Context ctx, Planned p) {
		List<Planned> list = all(ctx);
		for (int i = list.size() - 1; i >= 0; i--) {
			if (list.get(i).id == p.id) {
				list.remove(i);
			}
		}
		list.add(p);
		write(ctx, list);
	}

	static synchronized void remove(Context ctx, int id) {
		List<Planned> list = all(ctx);
		for (int i = list.size() - 1; i >= 0; i--) {
			if (list.get(i).id == id) {
				list.remove(i);
			}
		}
		write(ctx, list);
	}

	static synchronized void clear(Context ctx) {
		prefs(ctx).edit().putString(KEY_PLANNED, "[]").apply();
	}

	/** Stores the done Spieltag exactly (no maximum), so a corrected clock never leaves a far-future key behind. */
	static synchronized void setDone(Context ctx, int dayKey) {
		prefs(ctx).edit().putInt(KEY_DONE, dayKey).apply();
	}

	/** Allowed window for showing reminders (minutes of the local day), from GDScript Balance.REMIND_EARLIEST/LATEST. */
	static synchronized void setWindow(Context ctx, int earliest, int latest) {
		prefs(ctx).edit().putInt(KEY_EARLIEST, earliest).putInt(KEY_LATEST, latest).apply();
	}

	static synchronized int earliest(Context ctx) {
		return prefs(ctx).getInt(KEY_EARLIEST, DEFAULT_EARLIEST);
	}

	static synchronized int latest(Context ctx) {
		return prefs(ctx).getInt(KEY_LATEST, DEFAULT_LATEST);
	}

	static synchronized int done(Context ctx) {
		return prefs(ctx).getInt(KEY_DONE, Integer.MIN_VALUE);
	}
}
