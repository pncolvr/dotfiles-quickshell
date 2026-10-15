import test from 'node:test';
import assert from 'node:assert/strict';
import * as launchers from '../../src/services/projects/ProjectLaunchers.mjs';
const rules = [
    {id:'code',name:'Code',offerFolder:true,useFileNames:true,extensions:['.code-workspace'],command:['code'],profiles:{work:'Work',personal:'Personal'},arguments:['{path}','--profile','{profile}'],windowClass:'code',windowTitlePrefix:'{folderName}'},
    {id:'godot',name:'Godot',extensions:['.godot'],command:['godot'],arguments:['--editor','{path}'],folderArguments:['--editor','--path','{path}']},
    {id:'custom',name:'Custom editor',extensions:['.sampleproj'],command:['custom-editor'],arguments:['{path}','{directory}','{project}','{name}']}
];
const project = {path:'/projects/Game $value;`literal`',name:'Game',workspaces:[]};
test('configured extensions control matching and included choices', () => {
    assert.deepEqual(launchers.extensions(rules),['.code-workspace','.godot','.sampleproj']);
    assert.equal(launchers.forFile(project.path+'/Upper.GODOT',rules).id,'godot');
    assert.equal(launchers.forFile(project.path+'/nested.godot/plain.txt',rules),undefined);
    project.workspaces = [{path:project.path+'/project.godot',name:'project',included:true},
        {path:project.path+'/nested/project.godot',name:'project',included:false}];
    assert.equal(launchers.title(project.workspaces[0],project,rules),'Open in Godot');
    project.workspaces[1].included=true;
    assert.equal(launchers.title(project.workspaces[0],project,rules),'Open in Godot · project.godot');
    assert.equal(launchers.title(project.workspaces[1],project,rules),'Open in Godot · nested/project.godot');
    assert.deepEqual(launchers.includedFiles(project,[]),[]);
});
test('argv preserves exact paths, profiles and editor-specific flags', () => {
    const path = project.path+'/file {profile}.sampleproj';
    assert.deepEqual(launchers.prepare(rules[2],path,project,'Personal').command,
        ['custom-editor',path,project.path,project.path,'Game']);
    const godot=launchers.prepare(rules[1],project.path+'/project.godot',project,'Work');
    assert.deepEqual(godot.command,['godot','--editor',project.path+'/project.godot']);
    assert.equal(godot.windowClass,'');
    assert.deepEqual(launchers.prepare(rules[1],project.path,project,'Work').command,['godot','--editor','--path',project.path]);
    assert.deepEqual(launchers.prepare(rules[0],project.path,project,'personal').command,['code',project.path,'--profile','Personal']);
});
test('invalid configuration reports errors rather than executing a shell string', () => {
    assert.throws(()=>launchers.extensions([{extensions:['*.godot']}]),/literal suffix/);
    assert.throws(()=>launchers.prepare({command:'godot'},project.path,project,'Work'),/command/);
    assert.throws(()=>launchers.prepare({command:['code'],profiles:{work:'Work',personal:'Personal'},arguments:['{unknown}']},project.path,project,'Work'),/placeholder/);
});

test('one inferred action skips the chooser; mixed project retains every relevant app', () => {
    const game={...project,workspaces:[{path:project.path+'/project.godot',name:'project',included:true}]};
    assert.deepEqual(launchers.choices(game,rules,'code').map(row=>row.title),['Open in Godot']);
    game.workspaces.push({path:project.path+'/Game.code-workspace',name:'Game',included:true});
    assert.deepEqual(launchers.choices(game,rules,'code').map(row=>row.title),['Open in Code','Open in Godot','Game']);
    game.workspaces=[];
    assert.deepEqual(launchers.choices(game,rules,'code').map(row=>row.title),['Open in Code']);
    assert.throws(()=>launchers.choices(game,rules,'unknown'),/default project app/);
});


test('app actions sort alphabetically above named files regardless of input order', () => {
    const mixed = {...project,workspaces:[
        {path:project.path+'/zebra.code-workspace',name:'zebra',included:true},
        {path:project.path+'/alpha.code-workspace',name:'Alpha',included:true},
        {path:project.path+'/open.code-workspace',name:'Open in Aardvark',included:true},
        {path:project.path+'/project.godot',name:'project',included:true},
        {path:project.path+'/Game.sampleproj',name:'Game',included:true}
    ]};
    const expected = ['Open in Code','Open in Custom editor','Open in Godot','Alpha','Open in Aardvark','zebra'];
    assert.deepEqual(launchers.choices(mixed,rules,'code').map(row=>row.title),expected);
    mixed.workspaces.reverse();
    assert.deepEqual(launchers.choices(mixed,[...rules].reverse(),'code').map(row=>row.title),expected);
});


test('each app resolves its own profile and falls back to the project category', () => {
    const custom = {...rules[2],arguments:['{profile}'],profiles:{personal:'Custom personal'}};
    assert.deepEqual(launchers.prepare(custom,project.path,project,'personal').command,['custom-editor','Custom personal']);
    assert.deepEqual(launchers.prepare(custom,project.path,project,'work').command,['custom-editor','work']);
    assert.deepEqual(launchers.prepare({...custom,profiles:undefined},project.path,project,'personal').command,['custom-editor','personal']);
    assert.deepEqual(launchers.prepare(rules[0],project.path,project,'work').command,['code',project.path,'--profile','Work']);
});
