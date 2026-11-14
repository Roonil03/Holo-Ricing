/* Original project code, MIT licensed. See LICENSE. */
const Desklet = imports.ui.desklet;
const Settings = imports.ui.settings;
const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
const Pango = imports.gi.Pango;
const St = imports.gi.St;

const PREFIX = 'org.mpris.MediaPlayer2.';
const PATH = '/org/mpris/MediaPlayer2';
const PLAYER = 'org.mpris.MediaPlayer2.Player';

function unpack(value) {
    while (value instanceof GLib.Variant) value = value.deep_unpack();
    return value;
}

// Keep untrusted player metadata bounded and on one line before rendering it.
function boundedText(value) {
    return value.slice(0, 512).replace(/[\uD800-\uDBFF]$/, '');
}

function displayText(value) {
    value = unpack(value);
    if (typeof value !== 'string') return '';
    return boundedText(value).replace(/[\x00-\x1f\x7f-\x9f\u2028\u2029]+/g, ' ').trim();
}

function MediaDesklet(metadata, id) { this._init(metadata, id); }
MediaDesklet.prototype = {
    __proto__: Desklet.Desklet.prototype,
    _init: function(metadata, id) {
        Desklet.Desklet.prototype._init.call(this, metadata, id);
        this.alive = true;
        this.generation = 0;
        this.selected = null;
        this.bus = Gio.DBus.session;
        this.settings = new Settings.DeskletSettings(this, metadata.uuid, id);
        for (let key of ['background', 'foreground', 'accent'])
            this.settings.bindProperty(Settings.BindingDirection.IN, key, key, () => this.updateStyle());
        this.box = new St.BoxLayout({vertical: true, width: 360});
        this.title = new St.Label({text: 'No media playing', width: 340});
        this.title.clutter_text.set_single_line_mode(true);
        this.title.clutter_text.set_ellipsize(Pango.EllipsizeMode.END);
        this.box.add_actor(this.title);
        this.controls = new St.BoxLayout({vertical: false});
        this.buttons = {};
        for (let [label, method] of [['Previous', 'Previous'], ['Play / Pause', 'PlayPause'], ['Next', 'Next']]) {
            let button = new St.Button({label: label, reactive: true, can_focus: true});
            button.connect('clicked', () => this.control(method));
            this.buttons[method] = button;
            this.controls.add_actor(button);
        }
        this.box.add_actor(this.controls);
        this.setContent(this.box);
        this.updateStyle();
        this.ownerSignal = this.bus.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus', 'NameOwnerChanged', '/org/freedesktop/DBus', null, Gio.DBusSignalFlags.NONE,
            (bus, sender, path, iface, signal, params) => {
                let [name] = params.deep_unpack();
                if (name.startsWith(PREFIX)) this.refresh();
            });
        this.propertiesSignal = this.bus.signal_subscribe(null, 'org.freedesktop.DBus.Properties', 'PropertiesChanged', PATH, null, Gio.DBusSignalFlags.NONE,
            (bus, sender, path, iface, signal, params) => {
                let [name] = params.deep_unpack();
                if (name === PLAYER) this.refresh();
            });
        this.refresh();
    },
    updateStyle: function() {
        if (!this.box) return;
        this.box.style = `background-color: ${this.background}; color: ${this.foreground}; padding: 10px; border-radius: 8px;`;
        this.title.style = `color: ${this.foreground}; padding-bottom: 6px;`;
        for (let button of Object.values(this.buttons)) button.style = `color: ${this.accent}; padding: 5px;`;
    },
    refresh: function() {
        if (!this.alive) return;
        let generation = ++this.generation;
        this.bus.call('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ListNames', null, null, Gio.DBusCallFlags.NONE, 3000, null,
            (bus, result) => {
                if (!this.alive || generation !== this.generation) return;
                let names;
                try { names = bus.call_finish(result).deep_unpack()[0].filter(n => n.startsWith(PREFIX)).sort(); }
                catch (e) { this.selected = null; this.title.set_text('No media player'); return; }
                if (!names.length) { this.selected = null; this.title.set_text('No media player'); return; }
                let pending = names.length, players = [];
                for (let name of names) {
                    bus.call(name, PATH, 'org.freedesktop.DBus.Properties', 'GetAll', new GLib.Variant('(s)', [PLAYER]), null, Gio.DBusCallFlags.NONE, 3000, null,
                        (connection, response) => {
                            if (!this.alive || generation !== this.generation) return;
                            try {
                                let values = connection.call_finish(response).deep_unpack()[0];
                                players.push({name: name, status: unpack(values.PlaybackStatus), metadata: unpack(values.Metadata) || {}});
                            } catch (e) { /* Player exited during discovery. */ }
                            if (--pending !== 0) return;
                            players.sort((a, b) => (a.status === 'Playing' ? 0 : 1) - (b.status === 'Playing' ? 0 : 1) || a.name.localeCompare(b.name));
                            let active = players[0];
                            if (!active) { this.selected = null; this.title.set_text('No media player'); return; }
                            this.selected = active.name;
                            let title = displayText(active.metadata['xesam:title']) || 'Unknown track';
                            let artists = unpack(active.metadata['xesam:artist']);
                            if (!Array.isArray(artists)) artists = [];
                            artists = artists.slice(0, 8).map(displayText).filter(Boolean);
                            this.title.set_text(boundedText((artists.length ? artists.join(', ') + ': ' : '') + title));
                        });
                }
            });
    },
    control: function(method) {
        if (!this.alive || !this.selected) return;
        this.bus.call(this.selected, PATH, PLAYER, method, null, null, Gio.DBusCallFlags.NONE, 3000, null,
            (bus, result) => { try { bus.call_finish(result); } catch (e) { if (this.alive) this.refresh(); } });
    },
    on_desklet_removed: function() {
        this.alive = false;
        this.generation++;
        this.bus.signal_unsubscribe(this.ownerSignal);
        this.bus.signal_unsubscribe(this.propertiesSignal);
        this.settings.finalize();
    }
};
function main(metadata, deskletId) { return new MediaDesklet(metadata, deskletId); }
