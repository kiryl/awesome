-- Configuration file for ldoc

project='awesome'
title='awesome API documentation'
description='API documentation for awesome, a highly configurable X window manager (version @AWESOME_VERSION@).'

-- More on it: https://github.com/stevedonovan/LDoc/blob/master/doc/doc.md#markdown-support
format='discount'
dir='../doc'

-- Make the docs prettier
pretty='lua'
style="!pale"
backtick_references=true
merge=true
use_markdown_titles=true
wrap=true
topics={
    '00-authors.md',
    '01-readme.md',
    '02-contributing.md',
    '03-declarative-layout.md',
    '04-new-widgets.md',
}

-- Setup @client to be an alias for "@tparam client.object"
tparam_alias('client', 'client.object')
tparam_alias('tag', 'tag')
-- Should be default, but is not.  Sets up "@tab" => "@tparam table".
tparam_alias('tab', 'table')

-- Hack to get the functions and method on top of the signals and properties
new_type("function", "Functions")
-- Documentation for objects properties
new_type("property", "Object properties", false, "Type")
-- New type for signals
new_type("signal", "Signals", false, "Arguments")
-- Allow objects to define a set of beautiful properties affecting them
new_type("beautiful", "Theme variables", false, "Type")
-- Put deprecated methods in their own section
new_type("deprecated", "Deprecated functions", false, "param")
-- For the legacy stateless layout related functions
new_type("legacylayout", "Layout related functions", false, "param")

-- More fitting section names
kind_names={topic='Documentation', module='Libraries'}

-- Sort modules alphabetically
sort_modules=true

file = {
    -- C parts of libraries
    '../dbus.c',
    '../keygrabber.c',
    '../luaa.c',
    '../mouse.c',
    '../mousegrabber.c',
    '../root.c',
    '../selection.c',
    '../spawn.c',
    '../xkb.c',
    '../common/luaobject.c',
    '../objects/',
    -- LUA libraries
    '../lib/',
    -- Old APIs the user should not longer use directly
    '../../docs/aliases/awful_client.lua',
    '../../docs/aliases/awful_screen.lua',
    '../../docs/aliases/awful_tag.lua',
    exclude = {
        -- exclude these modules, as they do not contain any written
        -- documentation
        '../lib/awful/autofocus.lua',
        '../lib/awful/dbus.lua',
        '../lib/awful/init.lua',
        '../lib/awful/remote.lua',
        '../lib/awful/startup_notification.lua',
        '../lib/gears/init.lua',
        '../lib/wibox/layout/init.lua',
        '../lib/wibox/widget/init.lua',

        -- Ignore some parts of the widget library
        '../lib/awful/widget/init.lua',

        -- exclude layout, but we need an extra bit of documentation elsewhere.
        '../lib/awful/layout/suit/'
    }
}

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
