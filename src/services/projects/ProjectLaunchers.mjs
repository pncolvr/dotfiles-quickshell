// Matching and argv construction are shared by every configured editor.
export function extensions(launchers) {
    const values = launchers.reduce((values, launcher) => values.concat(launcher.extensions ?? []), []);
    if (values.some(value => typeof value !== "string" || !/^\.[a-z0-9][a-z0-9._-]*$/i.test(value)))
        throw new Error("projects.errors.invalidExtensions");
    return [...new Set(values.map(value => value.toLowerCase()))];
}
export function forFile(path, launchers) {
    const name = path.slice(path.lastIndexOf("/") + 1).toLowerCase();
    return launchers.find(launcher => (launcher.extensions ?? []).some(extension => name.endsWith(extension.toLowerCase())));
}
export function includedFiles(project, launchers) {
    return project.workspaces.filter(file => file.included && forFile(file.path, launchers));
}
export function title(file, project, launchers, translate) {
    const launcher = forFile(file.path, launchers);
    if (launcher?.useFileNames) return file.name;
    const multiple = includedFiles(project, launchers).filter(other => forFile(other.path, launchers) === launcher).length > 1;
    return translate("projects.actions.openIn",[launcher.name || launcher.id]) + (multiple ? " · " + file.path.slice(project.path.length + 1) : "");
}
export function choices(project, launchers, defaultApp, translate) {
    const files = includedFiles(project, launchers);
    const row = (app, path, label) => ({id:app.id + ":" + path, title:label, subtitle:path,
        result:path, launcherId:app.id, category:project.category});
    if (!files.length) {
        const app = launchers.find(app => app.id === defaultApp);
        if (!app) throw new Error("projects.errors.defaultApp");
        return [row(app, project.path, translate("projects.actions.openIn",[app.name || app.id]))];
    }
    const appRows = [];
    const fileRows = [];
    for (const app of launchers) {
        if (app.offerFolder && files.some(file => forFile(file.path, launchers) === app))
            appRows.push(row(app, project.path, translate("projects.actions.openIn",[app.name || app.id])));
    }
    for (const file of files) {
        const app = forFile(file.path, launchers);
        const rows = app.useFileNames ? fileRows : appRows;
        rows.push(row(app, file.path, title(file, project, launchers, translate)));
    }
    const alphabetical = (left, right) => left.title.localeCompare(right.title, undefined, {sensitivity: "base"})
        || left.id.localeCompare(right.id);
    return appRows.sort(alphabetical).concat(fileRows.sort(alphabetical));
}
export function prepare(launcher, path, project, category, workModeEnabled=true) {
    if (!launcher || !Array.isArray(launcher.command) || !launcher.command.length
        || launcher.command.some(value => typeof value !== "string" || !value))
        throw new Error("projects.errors.command");
    let args = (path === project.path ? launcher.folderArguments : undefined) ?? launcher.arguments ?? [];
    if (!Array.isArray(args)) throw new Error("projects.errors.argumentsType");
    if (workModeEnabled) args=args.concat(launcher.profileArguments??[]);
    const directory = path === project.path ? path : path.slice(0, path.lastIndexOf("/")) || "/";
    const profile = launcher.profiles?.[category] || category;
    const values = {path, project:project.path, directory, name:project.name,
        folderName:directory.split("/").pop(), profile};
    const expand = value => {
        if (typeof value !== "string") throw new Error("projects.errors.argumentType");
        return value.replace(/\{([a-zA-Z]+)\}/g, (token, key) => {
            if (!Object.prototype.hasOwnProperty.call(values, key)) throw Object.assign(new Error("projects.errors.unknownPlaceholder"), {args:[token]});
            return values[key];
        });
    };
    return {command:launcher.command.concat(args).map(expand),
        windowClass:launcher.windowClass ?? "", windowTitlePrefix:expand(launcher.windowTitlePrefix ?? "")};
}
