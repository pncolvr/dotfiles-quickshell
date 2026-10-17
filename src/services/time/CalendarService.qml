pragma Singleton

import "../../i18n"
import QtQml
import Quickshell
import "../"
import "../../config"
import "../../theme"

Singleton {
    id: root

    enum DayStyle { Invalid, Regular, Weekend, Holiday, ClockChangeEve, Today }
    enum Direction { Forward, Backward }

    property var _transitions: ({})
    readonly property string currentDateKey: Qt.formatDateTime(new Date(TimeService.time), "yyyy-MM-dd")
    readonly property string clockChangeNotice: warningFor(new Date(currentDateKey + "T12:00:00"))

    Connections {
        target: Config
        function onCalendarMunicipalHolidaysChanged() { root._holidaysByYear = ({}) }
    }

    Connections {
        target: Translations
        function onLanguageChanged() { root._holidaysByYear = ({}) }
    }

    function transitionsFor(year) {
        if (_transitions[year]) return _transitions[year];
        let events = [];
        if (Number.isInteger(year) && year >= 2002) {
            events = [_clockChange(year, 2), _clockChange(year, 9)];
        }
        _transitions[year] = events;
        return events;
    }

    function _clockChange(year, month) {
        const day = 31 - new Date(Date.UTC(year, month, 31)).getUTCDay();
        const instant = Date.UTC(year, month, day, 1);
        const spring = month === 2;
        const before = spring ? 0 : 3600;
        const after = spring ? 3600 : 0;
        const civil = offset => new Date(instant + offset * 1000).toISOString().slice(0, 19);
        const date = civil(before).slice(0, 10);
        const eve = new Date(Date.UTC(year, month, day - 1)).toISOString().slice(0, 10);
        return {date: date, eve: eve, old: civil(before), new: civil(after),
            instant: instant, before: before, after: after};
    }

    function transitionFor(date, eve = false) {
        const key = _key(date);
        return transitionsFor(date.getFullYear()).find(event => (eve ? event.eve : event.date) === key) || null;
    }

    function direction(event) {
        return event.after > event.before ? CalendarService.Direction.Forward : CalendarService.Direction.Backward;
    }

    function transitionText(event, tomorrow = false) {
        const forward = direction(event) === CalendarService.Direction.Forward;
        const key = forward ? "calendar.change.forward" : "calendar.change.back";
        return Translations.text(key + (tomorrow ? "Tomorrow" : ""),
            [event.old.slice(11).replace(/:00$/, ""), event.new.slice(11).replace(/:00$/, "")]);
    }

    function tooltipText(text) {
        return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            .replace(/→/g, '<font face="' + Theme.fontFamilyIcons + '">' + Theme.rightIcon + '</font>')
            .replace(/\n/g, "<br>");
    }

    function warningFor(date) {
        const event = transitionFor(date, true);
        return event ? tooltipText(transitionText(event, true)) : "";
    }

    function dayTooltip(date) {
        const parts = [];
        const holiday = holidayFor(date);
        if (holiday) parts.push(holiday);
        const eve = transitionFor(date, true);
        const transition = transitionFor(date);
        if (eve) parts.push(transitionText(eve, _key(date) === currentDateKey));
        if (transition) parts.push(transitionText(transition));
        return tooltipText(parts.join("\n") || Translations.text("calendar.actions.createEvent"));
    }

    function dayStyle(date, valid, today) {
        if (!valid) return CalendarService.DayStyle.Invalid;
        if (transitionFor(date, true)) return CalendarService.DayStyle.ClockChangeEve;
        if (today) return CalendarService.DayStyle.Today;
        if (holidayFor(date)) return CalendarService.DayStyle.Holiday;
        if (date.getDay() === 0 || date.getDay() === 6) return CalendarService.DayStyle.Weekend;
        return CalendarService.DayStyle.Regular;
    }

    property var _holidaysByYear: ({})

    function openDate(date) {
        Qt.openUrlExternally(eventUrlFor(date));
    }

    function eventUrlFor(date) {
        const event = transitionFor(date, true) || transitionFor(date);
        if (!event) {
            const start = _key(date).replace(/-/g, "");
            const end = _key(addDays(date, 1)).replace(/-/g, "");
            return Config.calendarEventUrl + "&dates=" + encodeURIComponent(start + "/" + end)
                + "&ctz=Europe%2FLisbon";
        }
        const parts = event.eve.split("-").map(Number);
        const start = Date.UTC(parts[0], parts[1] - 1, parts[2], Config.calendarClockChangeEventHour,
            Config.calendarClockChangeEventMinute) - event.before * 1000;
        const end = start + Config.calendarClockChangeEventDurationMinutes * 60000;
        const stamp = value => new Date(value).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
        const title = Translations.text(direction(event) === CalendarService.Direction.Forward
            ? "calendar.change.forwardTonight" : "calendar.change.backTonight");
        return Config.calendarEventUrl + "&text=" + encodeURIComponent(title)
            + "&dates=" + encodeURIComponent(stamp(start) + "/" + stamp(end))
            + "&ctz=Europe%2FLisbon"
            + "&details=" + encodeURIComponent(transitionText(event));
    }

    function formatDate(date, referenceTime) {
        if (!date)
            return "";

        const d = new Date(date);
        const d2 = new Date(referenceTime ?? Date.now());
        if (!Number.isFinite(d.getTime()) || !Number.isFinite(d2.getTime()))
            return "";
        const time = Qt.formatTime(d, "hh:mm");
        if (isSameDay(d, d2)) return Translations.text("calendar.relative.todayAt", [time]);
        if (isSameDay(d, addDays(d2, 1))) return Translations.text("calendar.relative.tomorrowAt", [time]);
        return Translations.text("calendar.relative.dateAt", [Qt.formatDate(d, "yyyy-MM-dd"), time]);
    }

    function addDays(value, days) {
        const date = new Date(value);
        date.setDate(date.getDate() + days);
        return date;
    }

    function isSameDay(first, second) {
        return first.getDate() === second.getDate()
            && first.getMonth() === second.getMonth()
            && first.getFullYear() === second.getFullYear();
    }

    function _pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function _key(date) {
        return `${date.getFullYear()}-${_pad(date.getMonth() + 1)}-${_pad(date.getDate())}`;
    }
    
    // https://en.wikipedia.org/wiki/Date_of_Easter#Anonymous_Gregorian_algorithm
    function _computeEaster(year) {
        const a = year % 19;
        const b = Math.floor(year / 100);
        const c = year % 100;
        const d = Math.floor(b / 4);
        const e = b % 4;
        const f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - d - g + 15) % 30;
        const i = Math.floor(c / 4);
        const k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7;
        const m = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * m + 114) / 31);
        const day = ((h + l - 7 * m + 114) % 31) + 1;
        return new Date(year, month - 1, day);
    }

    function computeHolidaysForYear(year) {
        if (_holidaysByYear[year])
            return;

        const easter = _computeEaster(year);
        // https://en.wikipedia.org/wiki/Public_holidays_in_Portugal
        const goodFriday = addDays(easter, -2);
        const carnival = addDays(easter, -47);
        const corpusChristi = addDays(easter, 60);

        const entries = [
            [new Date(year, 0, 1), Translations.text("calendar.holidays.newYear")],
            [carnival, Translations.text("calendar.holidays.carnival")],
            [goodFriday, Translations.text("calendar.holidays.goodFriday")],
            [easter, Translations.text("calendar.holidays.easter")],
            [new Date(year, 3, 25), Translations.text("calendar.holidays.freedom")],
            [new Date(year, 4, 1), Translations.text("calendar.holidays.labour")],
            [new Date(year, 5, 10), Translations.text("calendar.holidays.portugal")],
            [corpusChristi, Translations.text("calendar.holidays.corpusChristi")],
            [new Date(year, 7, 15), Translations.text("calendar.holidays.assumption")],
            [new Date(year, 9, 5), Translations.text("calendar.holidays.republic")],
            [new Date(year, 10, 1), Translations.text("calendar.holidays.allSaints")],
            [new Date(year, 11, 1), Translations.text("calendar.holidays.independence")],
            [new Date(year, 11, 8), Translations.text("calendar.holidays.immaculateConception")],
            [new Date(year, 11, 25), Translations.text("calendar.holidays.christmas")]
        ];

        for (const holiday of Config.calendarMunicipalHolidays) {
            if (!holiday || !Number.isInteger(holiday.month) || !Number.isInteger(holiday.day)
                || holiday.month < 1 || holiday.month > 12 || holiday.day < 1
                || typeof holiday.name !== "string" || !holiday.name.trim()) continue;
            const date = new Date(year, holiday.month - 1, holiday.day);
            if (date.getFullYear() !== year || date.getMonth() !== holiday.month - 1
                || date.getDate() !== holiday.day) continue;
            entries.push([date, holiday.name.trim()]);
        }

        const map = {};
        for (const [date, name] of entries) {
            const key = _key(date);
            const names = map[key] ? map[key].split("\n") : [];
            if (!names.includes(name)) names.push(name);
            map[key] = names.join("\n");
        }
        _holidaysByYear[year] = map;
    }

    function hasHolidays(year, month = -1) {
        computeHolidaysForYear(year);
        return Object.keys(_holidaysByYear[year]).some(key => month < 0 || Number(key.slice(5, 7)) === month + 1);
    }

    function holidayFor(date) {
        const d = (date instanceof Date) ? date : new Date(date)
        const year = d.getFullYear()

        if (!_holidaysByYear[year]) {
            computeHolidaysForYear(year)
        }

        const yearMap = _holidaysByYear[year]
        return yearMap[_key(d)] || null
    }
}
