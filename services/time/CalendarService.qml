pragma Singleton

import QtQuick
import Quickshell
import "../../config"

Singleton {

    property var _holidaysByYear: ({})

    function dateUrl(date) {
        const y = date.getFullYear();
        const m = date.getMonth() + 1;
        const d = date.getDate();
        return `${Config.calendarUrl}/${y}/${m}/${d}`;
    }

    function openDate(date) {
        Qt.openUrlExternally(dateUrl(date));
    }

    function formatDate(date) {
        if (!date)
            return "";
        const time = " 'at' hh:mm";
        let format = "yyyy-MM-dd";
        const d = new Date(date);
        const d2 = new Date();
        if (d.isSameDay(d2)) {
            format = "'today'";
        } else if (d.isSameDay(d2.addDays(1))) {
            format = "'tomorrow'";
        }
        return Qt.formatDateTime(d, format + time);
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
        const goodFriday = easter.addDays(-2);
        const carnival = easter.addDays(-47);
        const corpusChristi = easter.addDays(60);

        const entries = [
            [new Date(year, 0, 1), "Ano Novo"],
            [carnival, "Carnaval (facultativo)"],
            [goodFriday, "Sexta-Feira Santa"],
            [easter, "Páscoa"],
            [new Date(year, 3, 25), "Dia da Liberdade"],
            [new Date(year, 4, 1), "Dia do Trabalhador"],
            [new Date(year, 4, 22), "Dia de Leiria"],
            [new Date(year, 5, 10), "Dia de Portugal"],
            [corpusChristi, "Corpo de Deus"],
            [new Date(year, 7, 15), "Assunção de Nossa Senhora"],
            [new Date(year, 9, 5), "Implantação da República"],
            [new Date(year, 10, 1), "Todos os Santos"],
            [new Date(year, 11, 1), "Restauração da Independência"],
            [new Date(year, 11, 8), "Imaculada Conceição"],
            [new Date(year, 11, 25), "Natal"]
        ];

        const map = {};
        for (const [date, name] of entries) {
            map[_key(date)] = name;
        }
        _holidaysByYear[year] = map;
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

    Component.onCompleted: {
        Date.prototype.addDays = function (days) {
            var date = new Date(this.valueOf());
            date.setDate(date.getDate() + days);
            return date;
        };

        Date.prototype.isSameDay = function (date) {
            const now = new Date(this.valueOf());
            return now.getDate() === date.getDate() && now.getMonth() === date.getMonth() && now.getFullYear() === date.getFullYear();
        };
    }
}
