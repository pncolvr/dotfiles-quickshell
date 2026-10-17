#!/usr/bin/env node
import fs from 'node:fs';
import {spawn} from 'node:child_process';
import p from 'node:path';const dir=process.env.REMOTE_TEST_DIR,program=p.basename(process.argv[1]),args=process.argv.slice(2)
fs.appendFileSync(dir+'/actions',JSON.stringify({program,args,pid:process.pid})+'\n')
switch(program){
case 'probe': {
 const port=Number(args.at(-1));const ready=port>=49152 ? fs.existsSync(dir+'/port-'+port) : !fs.existsSync(dir+'/not-ready');process.exit(ready?0:1);break
}
case 'getent':console.log('192.0.2.5 STREAM reserved');process.exit(0);break
case 'ssh': {
 if(args.includes('-G')) {
  console.log('hostname '+args.at(-1));console.log('user '+(args.includes('-l')?args[args.indexOf('-l')+1]:'config-user'));
  process.exit(0);
 }
 if(fs.existsSync(dir+'/ssh-fail'))process.exit(3)
 const forward=args[args.indexOf('-L')+1];if(args.includes('-L'))fs.writeFileSync(dir+'/port-'+forward.split(':')[1],'ready');break
}
case 'virsh':
 if(args.includes('domid'))console.log(fs.existsSync(dir+'/vm-running')?'42':'-');
 if(args.includes('start'))fs.writeFileSync(dir+'/vm-running','running');
 if(args.includes('shutdown'))fs.rmSync(dir+'/vm-running',{force:true});
 process.exit(0);break
case 'alerts':process.exit(0);break
case 'terminal': {
 let command=args.slice(args.indexOf('-e')+1);
 // Ghostty 1.3.1's Bash integration joins argv into shell text without quoting
 // (setupBash / ShellCommandBuilder). Exercise that boundary, not just execvp.
 if(p.basename(command[0])==='bash') command=['/bin/sh','-c',[command[0],'--posix',...command.slice(1)].join(' ')];
 const child=spawn(command[0],command.slice(1),{stdio:'inherit'});
 child.on('exit',(code)=>process.exit(code??1));
 process.on('SIGTERM',()=>child.kill('SIGHUP'));
 break
}
case 'rdp':fs.writeFileSync(dir+'/rdp-'+process.pid,fs.readFileSync(0));break
}
const timer=setInterval(()=>{},100)
process.on('SIGTERM',()=>{
 if(program==='ssh' && args.includes('-L')){const file=dir+'/port-'+args[args.indexOf('-L')+1].split(':')[1];try{fs.unlinkSync(file)}catch{}}
 clearInterval(timer);process.exit(0)
})
