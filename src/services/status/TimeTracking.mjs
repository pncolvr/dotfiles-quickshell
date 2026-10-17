import * as Dates from '../time/CalendarDates.mjs'

export function cutoff(now=Date.now()) {
    const date=new Date(now),year=date.getFullYear()-1,month=date.getMonth()
    return new Date(year,month,Math.min(date.getDate(),new Date(year,month+1,0).getDate()),
        date.getHours(),date.getMinutes(),date.getSeconds(),date.getMilliseconds()).getTime()
}
export function dateKey(date) {
    return Dates.key(date)
}
export function days(sessions,currentId=0) {
    const result={}
    for(const session of sessions) {
        let start=session.start_ms
        while(start<session.end_ms) {
            const date=new Date(start),key=dateKey(date)
            const end=Math.min(session.end_ms,new Date(date.getFullYear(),date.getMonth(),date.getDate()+1).getTime())
            if(!(end>start))throw Error("status.errors.trackingBoundary")
            const day=result[key]??{date:key,work:0,personal:0,blocks:[]}
            day[session.mode]+=(end-start)/1000
            day.blocks.push({start,end,category:session.mode,ongoing:session.id===currentId && end===session.end_ms})
            result[key]=day;start=end
        }
    }
    return Object.values(result).sort((a,b)=>a.date.localeCompare(b.date))
}
function duration(value) {
    value=Math.max(0,Math.floor(value))
    return [Math.floor(value/3600),Math.floor(value%3600/60),value%60].map(number=>String(number).padStart(2,'0')).join(':')
}
function clock(at) {
    const date=new Date(at)
    return [date.getHours(),date.getMinutes(),date.getSeconds()].map(value=>String(value).padStart(2,'0')).join(':')
}
// Internal report grammar: Timecard.parse consumes these tokens independently of display language.
function render(values) {
    if(!values.length)return 'No completed time blocks found.'
    return values.map(day=>day.date+'\n  work '+duration(day.work)+'\n  personal '+duration(day.personal)+'\n  blocks:\n'+
        day.blocks.map(block=>'    '+clock(block.start)+' '+clock(block.end)+' '+block.category+' '+duration((block.end-block.start)/1000)+(block.ongoing?' ongoing':'')).join('\n')).join('\n\n')
}
function renderRange(values, first, next) {
    const end=new Date(next);end.setDate(end.getDate()-1)
    const from=dateKey(first),to=dateKey(end)
    return from+' – '+to+'\n\n'+render(values.filter(day=>day.date>=from && day.date<=to))
}
export function recordedPeriods(sessions,now=Date.now()) {
    const recorded=days(sessions.map(session=>Object.assign({},session,{end_ms:Math.min(session.end_ms,now)})))
    const periods={week:[],month:[],dates:recorded.map(day=>day.date),first:recorded[0]?.date ?? '',last:recorded[recorded.length-1]?.date ?? ''}
    for (const kind of ['week','month'])
        periods[kind]=[...new Set(recorded.map(day=>Dates.key(Dates.start(new Date(day.date+'T12:00:00'),kind))))]
    return periods
}
export function periodReport(sessions,kind,date,currentId=0,now=Date.now()) {
    const period=Dates.key(Dates.start(date,kind))
    if (!recordedPeriods(sessions,now)[kind].includes(period)) return ''
    const retained=sessions.map(session=>Object.assign({},session,{end_ms:Math.min(session.end_ms,now)}))
        .filter(session=>session.end_ms>session.start_ms)
    return renderRange(days(retained,currentId),Dates.start(date,kind),Dates.shift(date,kind,1))
}
export function reports(sessions,now=Date.now(),currentId=0) {
    const values=days(sessions,currentId),today=new Date(now),key=dateKey(today)
    const monday=new Date(today.getFullYear(),today.getMonth(),today.getDate()-((today.getDay()+6)%7))
    const lastMonday=new Date(monday);lastMonday.setDate(lastMonday.getDate()-7)
    const nextMonday=new Date(monday);nextMonday.setDate(nextMonday.getDate()+7)
    const month=new Date(today.getFullYear(),today.getMonth(),1),lastMonth=new Date(today.getFullYear(),today.getMonth()-1,1)
    const range=(first,next)=>renderRange(values,first,next)
    const current=values.find(day=>day.date===key)
    return {date:key,summary:'work     '+duration(current?.work||0)+'\npersonal '+duration(current?.personal||0),
        today:render(values.filter(day=>day.date===key)),currentWeek:range(monday,nextMonday),lastWeek:range(lastMonday,monday),
        currentMonth:range(month,new Date(today.getFullYear(),today.getMonth()+1,1)),lastMonth:range(lastMonth,month)}
}
export function rules(value) {
    const directories = value.workDirectories ?? []
    const processes = value.processes ?? []
    if (!Array.isArray(directories) || directories.some(path => typeof path !== 'string'
        || !path.trim().startsWith('/') || /[\0\r\n]/.test(path)))
        throw Error("status.rules.errors.folders")
    if (!Array.isArray(processes) || processes.some(pattern => typeof pattern !== 'string'
        || !pattern.trim() || /[\0\r\n]/.test(pattern)))
        throw Error("status.rules.errors.processes")
    const workDirectories = directories.map(path => path.trim().replace(/\/+$/, '') || '/')
    return {workDirectories: [...new Set(workDirectories)], processes: [...new Set(processes.map(pattern => pattern.trim()))]}
}
