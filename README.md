Seeing as the website is down last I checked I figured I try running this locally,
so I added nix packaging scripts for this, and iteratively turned this into a local
website that does NOT provide a web API. A bit of a downside, but I didn't want to
bother with hosting docker containers if I didn't have to. I have a few QoL things
I'd like to support as well.

### Planned Additions
- [ ] Should be able to customize the resolution instead of defaulting to 1920x1080
- [ ] Molecule size should be customizeable
- [ ] Searchable dropdown for the compounds
### Chores
- [ ] Move away from `gulp.js`?
- [ ] coffeescript -> typescript
- [ ] more in line with modern browser APIs, cleanup div soup

# Avogadrio
Worship your favorite molecule by setting it as your wallpaper.

Avogadrio is a web app that will render your favourite molecule as a desktop wallpaper from either a compund name or
[SMILES structure](https://en.wikipedia.org/wiki/Simplified_molecular-input_line-entry_system). Molecule rendering
is designed to be powered by [smiles-drawer](https://github.com/reymond-group/smilesDrawer).

![Logo](logo.png)

## Prerequisites
You'll need to have a web server installed for hosting static files. Once you've done that you can proceed.

You'll also need [Node.js](https://nodejs.org/en/) and [npm](https://www.npmjs.com/) installed and working.

## Building
Clone the project down and open the folder in your favourite editor.

Install the npm packages necessary to build and run the website. Run the following in your terminal in the project root directory:

```
npm install
```

Gulp will have been installed. This will compile the [Less](http://lesscss.org/) and [CoffeeScript](http://coffeescript.org/) into CSS and JavaScript ready for production. Do this using the command:

```
gulp
```

This command will need running again every time you make a change to a Less or CoffeeScript file. If you're working on them, run `gulp watch` in a terminal to watch for file changes and compile accordingly.

## Acknowledgements
A big thank you to:

* [Nile Red](https://www.youtube.com/user/TheRedNile) inspired me to build this. I wasn't that big on chemistry until I came across his videos.
* [Jay Holtslander](https://codepen.io/j_holtslander/) put together the hamburger menu/sidebar combo in his [Pen](https://codepen.io/j_holtslander/pen/XmpMEp) on CodePen. I believe it's derived from earlier work by [maridlcrmn](https://bootsnipp.com/maridlcrmn).
* [Andre Plötze](https://github.com/andrepxx) created [pure-knob](https://github.com/andrepxx/pure-knob), which is used here for the rotation knob/wheel/dial thing.
* [Contributors to this awesome repo](https://github.com/spothq/cryptocurrency-icons) which provides the cryptocurrency donation icons in the web app (they aren't bundled here).
