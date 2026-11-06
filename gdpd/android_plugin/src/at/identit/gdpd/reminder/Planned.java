package at.identit.gdpd.reminder;

import java.util.Calendar;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * One planned reminder (docs/GDPD_TAEGLICH_CHARAKTER.md 5.5): wall-clock fields, converted with the device's
 * time zone only when the alarm is set, so daylight saving time and travel are handled by Android.
 */
final class Planned {
	final int id;
	final int year;
	final int month; // 1..12
	final int day;
	final int hour;
	final int minute;
	final String title;
	final String text;
	final String iconPath;
	final int dayKey;

	Planned(int id, int year, int month, int day, int hour, int minute, String title, String text, String iconPath,
			int dayKey) {
		this.id = id;
		this.year = year;
		this.month = month;
		this.day = day;
		this.hour = hour;
		this.minute = minute;
		this.title = title == null ? "" : title;
		this.text = text == null ? "" : text;
		this.iconPath = iconPath == null ? "" : iconPath;
		this.dayKey = dayKey;
	}

	/** Epoch milliseconds of the wall-clock time in the device's current time zone. */
	long millis() {
		Calendar c = Calendar.getInstance();
		c.clear();
		c.set(year, month - 1, day, hour, minute, 0);
		return c.getTimeInMillis();
	}

	JSONObject toJson() throws JSONException {
		JSONObject o = new JSONObject();
		o.put("id", id);
		o.put("year", year);
		o.put("month", month);
		o.put("day", day);
		o.put("hour", hour);
		o.put("minute", minute);
		o.put("title", title);
		o.put("text", text);
		o.put("icon", iconPath);
		o.put("key", dayKey);
		return o;
	}

	static Planned fromJson(JSONObject o) {
		return new Planned(o.optInt("id"), o.optInt("year"), o.optInt("month", 1), o.optInt("day", 1),
				o.optInt("hour"), o.optInt("minute"), o.optString("title", ""), o.optString("text", ""),
				o.optString("icon", ""), o.optInt("key", -1));
	}
}
