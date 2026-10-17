import assert from 'node:assert/strict';
import {cutoff, days, reports, periodReport, recordedPeriods, rules} from '../../src/services/status/TimeTracking.mjs';
import * as Dates from '../../src/services/time/CalendarDates.mjs';
import {prepare} from '../../src/services/projects/ProjectLaunchers.mjs';
const at=value=>new Date(value).getTime();
const session=(start,end,mode='work',id=1)=>({id,start_ms:at(start),end_ms:at(end),mode});
assert.equal(new Date(cutoff(at('2024-02-29T12:34:56'),36)).toISOString(),new Date('2021-02-28T12:34:56').toISOString());
assert.equal(new Date(cutoff(at('2024-02-29T12:34:56'),12)).toISOString(),new Date('2023-02-28T12:34:56').toISOString());
assert.equal(new Date(cutoff(at('2026-05-31T12:34:56'),1)).toISOString(),new Date('2026-04-30T12:34:56').toISOString());
assert.equal(new Date(cutoff(at('2026-10-17T12:34:56'),6)).toISOString(),new Date('2026-04-17T12:34:56').toISOString());
for(const months of [0,-1,1.5,NaN,undefined])assert.throws(()=>cutoff(at('2026-10-17T12:34:56'),months));
assert.equal(days([session('2026-03-29T00:00:00','2026-03-30T00:00:00')])[0].work,23*3600);
assert.equal(days([session('2026-10-25T00:00:00','2026-10-26T00:00:00')])[0].work,25*3600);
const split=days([session('2026-10-15T23:59:00','2026-10-16T00:01:00')],1);
assert.deepEqual(split.map(day=>[day.date,day.work,day.blocks[0].ongoing]),[['2026-10-15',60,false],['2026-10-16',60,true]]);
const report=reports([session('2026-10-16T09:00:00','2026-10-16T10:30:00')],at('2026-10-16T12:00:00'),1);
assert.match(report.today,/work 01:30:00/);
assert.match(report.today,/09:00:00 10:30:00 work 01:30:00 ongoing/);
assert.ok(report.currentWeek.startsWith('2026-10-12 – 2026-10-18'));
assert.ok(report.lastWeek.startsWith('2026-10-05 – 2026-10-11'));
assert.ok(report.currentMonth.startsWith('2026-10-01 – 2026-10-31'));
assert.ok(report.lastMonth.startsWith('2026-09-01 – 2026-09-30'));
const now=at('2026-10-17T12:00:00');
assert.match(periodReport([session('2026-01-01T09:00:00','2026-01-01T10:00:00')], 'week', new Date('2026-01-01T12:00:00'),0,now),/^2025-12-29 – 2026-01-04/);
assert.match(periodReport([session('2026-02-15T09:00:00','2026-02-15T10:00:00')], 'month', new Date('2026-02-15T12:00:00'),0,now),/^2026-02-01 – 2026-02-28/);
assert.match(periodReport([session('2024-02-15T09:00:00','2024-02-15T10:00:00')], 'month', new Date('2024-02-15T12:00:00'),0,at('2024-03-01T12:00:00')),/^2024-02-01 – 2024-02-29/);
assert.match(periodReport([session('2026-03-29T00:00:00','2026-03-30T00:00:00')], 'week', new Date('2026-03-29T12:00:00'),0,now),/work 23:00:00/);
assert.match(periodReport([session('2026-10-25T00:00:00','2026-10-26T00:00:00')], 'month', new Date('2026-10-01T12:00:00'),0,at('2026-10-26T12:00:00')),/work 25:00:00/);
assert.equal(periodReport([], 'week',new Date('2026-10-19T00:00:00'),0,now),'','future week rejected');
assert.equal(periodReport([], 'month',new Date('2025-09-01T00:00:00'),0,now),'','expired month rejected');
assert.equal(periodReport([], 'month',new Date('2025-10-01T00:00:00'),0,now),'','empty periods unavailable');
assert.match(periodReport([session('2025-10-17T11:00:00','2025-10-17T13:00:00')], 'month',new Date('2025-10-01T00:00:00'),0,now),/work 02:00:00/,'report reflects stored data rather than applying a second retention cutoff');
assert.throws(()=>periodReport([], 'day',new Date(now),0,now));
assert.equal(Dates.weekNumber(new Date('2026-01-01T12:00:00')),1);
assert.equal(Dates.weekNumber(new Date('2027-01-01T12:00:00')),53);
assert.equal(Dates.key(Dates.shift(new Date('2026-03-29T12:00:00'),'week',1)),'2026-03-30');
assert.equal(Dates.key(Dates.shift(new Date('2026-01-31T12:00:00'),'month',1)),'2026-02-01');
const available=recordedPeriods([
    session('2023-02-28T23:59:00','2023-03-01T00:01:00'),
    session('2026-10-16T09:00:00','2026-10-16T10:00:00'),
    session('2026-10-16T10:00:00','2026-10-16T11:00:00'),
    session('2026-11-01T09:00:00','2026-11-01T10:00:00')
],now);
assert.deepEqual(available.month,['2023-02-01','2023-03-01','2026-10-01'],'only recorded months, without a rolling cutoff');
assert.deepEqual(available.week,['2023-02-27','2026-10-12'],'unique recorded weeks; gaps and future-only data excluded');
assert.deepEqual([available.first,available.last],['2023-02-28','2026-10-16']);
assert.equal(Dates.adjacent(available.month,'2026-10-01',-1),'2023-03-01','navigation skips empty months');
assert.equal(Dates.adjacent(available.month,'2023-03-01',1),'2026-10-01');
assert.equal(Dates.adjacent([], '2026-10-01',1),'');
assert.match(periodReport([session('2023-02-28T09:00:00','2023-02-28T10:00:00')], 'month',new Date('2023-02-01T12:00:00'),0,now),/^2023-02-01 – 2023-02-28/,'stored data is not limited by picker retention settings');
assert.deepEqual(recordedPeriods([],now),{week:[],month:[],dates:[],first:'',last:''});
assert.deepEqual(rules({workDirectories:['/work/','/second folder','/work','/'],processes:['app','app','other']}),
    {workDirectories:['/work','/second folder','/'],processes:['app','other']});
assert.deepEqual(rules({}),{workDirectories:[],processes:[]});
assert.throws(()=>rules({workDirectories:'not an array'}));
assert.throws(()=>rules({workDirectories:['/valid',42]}));
assert.throws(()=>rules({workDirectories:['/valid','/bad\nfolder']}));
assert.throws(()=>rules({workDirectories:['/valid','relative']}));
assert.throws(()=>rules({processes:['bad\npattern']}));
const app={command:['code'],arguments:['{path}'],profileArguments:['--profile','{profile}'],profiles:{work:'Work'}};
const project={path:'/work/example',name:'example'};
assert.deepEqual(prepare(app,project.path,project,'work').command,['code',project.path,'--profile','Work']);
assert.deepEqual(prepare(app,project.path,project,'work',false).command,['code',project.path]);
console.log('PASS: local-day/DST reports, calendar retention, detection rules and optional app profiles');
