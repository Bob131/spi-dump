errordomain PluginError {
    UNKNOWN_PLUGIN,
    LOADING_FAILED
}

class PluginEngine<T> : Object {
    [Compact]
    class Plugin {
        public unowned Peas.PluginInfo info;
        public List<Object> extensions;

        public Plugin (Peas.PluginInfo info) {
            this.info = info;
        }
    }

    class PluginTable {
        HashTable<string, Plugin> plugins;

        static string get_key (Peas.PluginInfo info) {
            return info.get_name ();
        }

        public bool has_name (string name) {
            return name in plugins;
        }

        public bool contains (Peas.PluginInfo info) {
            return has_name (get_key (info));
        }

        public unowned Plugin get_for_name (string name)
            requires (has_name (name))
        {
            return plugins[name];
        }

        public unowned Plugin @get (Peas.PluginInfo info)
            requires (contains (info))
        {
            return this.get_for_name (get_key (info));
        }

        public void add (Peas.PluginInfo info) {
            if (info in this) {
                warn_if_fail (this[info].info == info);
                return;
            }

            plugins[get_key (info)] = new Plugin (info);
        }

        public void remove (Peas.PluginInfo info)
            requires (contains (info))
        {
            warn_if_fail (this[info].extensions.length () == 0);
            plugins.remove (get_key (info));
        }

        public PluginTable () {
            plugins = new HashTable<string, Plugin> (str_hash, str_equal);
        }
    }

    Peas.Engine engine;
    Peas.ExtensionSet extension_set;
    PluginTable plugins;

    public void add_search_path (string module_dir, string? data_dir = null) {
        engine.add_search_path (module_dir, data_dir);
    }

    public void prepend_search_path (
        string module_dir,
        string? data_dir = null
    ) {
        engine.prepend_search_path (module_dir, data_dir);
    }

    public new unowned List<T> @get (string plugin_name) throws PluginError {
        if (!plugins.has_name (plugin_name)) {
            unowned Peas.PluginInfo? info =
                engine.get_plugin_info (plugin_name);

            if (info == null)
                throw new PluginError.UNKNOWN_PLUGIN (
                    "Unknown plugin '%s'", plugin_name
                );

            plugins.add ((!) info);
        }

        unowned Plugin plugin = plugins.get_for_name (plugin_name);

        if (!plugin.info.is_loaded () && !engine.try_load_plugin (plugin.info))
        {
            try {
                plugin.info.is_available ();
                return_val_if_reached (null); // above should throw
            } catch (Error e) {
                if (e is Peas.PluginInfoError)
                    throw new PluginError.LOADING_FAILED (e.message);
                return_val_if_reached (null);
            }
        }

        return plugin.extensions;
    }

    public unowned List<Peas.PluginInfo> get_all () {
        return engine.get_plugin_list ();
    }

    public PluginEngine ()
        requires (typeof (T).is_a (typeof (Object)))
        requires (typeof (T).is_interface ())
    {
        engine = new Peas.Engine.with_nonglobal_loaders ();
        extension_set = new Peas.ExtensionSet (engine, typeof (T));
        plugins = new PluginTable ();

        extension_set.extension_added.connect ((info, extension) => {
            plugins.add (info);
            plugins[info].extensions.append (extension);
        });

        extension_set.extension_removed.connect ((info, extension) => {
            if (!plugins.contains (info))
                return;

            plugins[info].extensions.remove_all (extension);

            if (plugins[info].extensions.length () == 0)
                plugins.remove (info);
        });
    }
}
