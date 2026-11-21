(function () {
    // Original MIT code. Read CSS as data; never append it to this expression.
    const Gtk = imports.gi.Gtk;
    const GObject = imports.gi.GObject;
    const GLib = imports.gi.GLib;
    const screen = imports.gi.Gdk.Screen.get_default();
    const key = '_inaWindowControlsProvider';
    // Discover frames before changing any provider. A missing frame cannot
    // produce a successful live refresh or leave a new provider installed.
    const frames = Gtk.Window.list_toplevels().filter(
        widget => GObject.type_name_from_instance(widget) === 'MetaFrames');
    if (!screen || !frames.length)
        throw new Error('No Cinnamon frame windows are available');
    const path = GLib.build_filenamev([GLib.get_user_config_dir(), 'gtk-3.0', 'gtk.css']);
    let css = '';
    if (GLib.file_test(path, GLib.FileTest.EXISTS)) {
        const [loaded, contents] = GLib.file_get_contents(path);
        if (!loaded)
            throw new Error('Cannot read the installed GTK CSS');
        css = imports.byteArray.toString(contents);
    }
    const lines = css.split('\n').map(line => line.trim());
    const begins = lines.reduce((found, line, index) => {
        if (line === '/* Ina window controls begin */')
            found.push(index);
        return found;
    }, []);
    const ends = lines.reduce((found, line, index) => {
        if (line === '/* Ina window controls end */')
            found.push(index);
        return found;
    }, []);
    if (begins.length !== ends.length || begins.length > 1 ||
        (begins.length === 1 && begins[0] >= ends[0]))
        throw new Error('Malformed Ina window controls CSS block');
    // Replace our own provider on every apply; an empty restored block removes it.
    // The file remains authoritative for the next Cinnamon login.
    let provider = null;
    if (begins.length) {
        provider = new Gtk.CssProvider();
        // Load the complete file to retain surrounding user rules, their order,
        // and relative @imports. GTK parses this data; it is never JavaScript.
        provider.load_from_path(path);
    }
    // Muffin keeps detached style contexts; changing the file or notifying the
    // GTK theme setting alone does not rebuild their cached button colours.
    const previous = global[key] || null;
    let removedPrevious = false;
    let addedProvider = false;
    try {
        if (previous) {
            Gtk.StyleContext.remove_provider_for_screen(screen, previous);
            removedPrevious = true;
            delete global[key];
        }
        if (provider) {
            Gtk.StyleContext.add_provider_for_screen(screen, provider,
                                                     Gtk.STYLE_PROVIDER_PRIORITY_USER);
            addedProvider = true;
            global[key] = provider;
        }
        for (const frame of frames) {
            frame.reset_style();
            frame.emit('style-updated');
            frame.queue_draw();
        }
    } catch (error) {
        if (addedProvider) {
            Gtk.StyleContext.remove_provider_for_screen(screen, provider);
            delete global[key];
        }
        if (removedPrevious) {
            Gtk.StyleContext.add_provider_for_screen(screen, previous,
                                                     Gtk.STYLE_PROVIDER_PRIORITY_USER);
            global[key] = previous;
        }
        for (const frame of frames) {
            try {
                frame.reset_style();
                frame.emit('style-updated');
                frame.queue_draw();
            } catch (_) {
                // Preserve the original error if a frame vanished meanwhile.
            }
        }
        throw error;
    }
    return 'INA_WINDOW_CONTROLS_REFRESHED:' + frames.length;
})()
