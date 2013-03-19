NOTE: NOT YET FUNCTIONAL -- DO NOT USE
======================================

stars2evernote.rb -- convert from google reader json to evernote enex
=====================================================================

Version: 0.8

Stars2evernote.rb is a kludgy ruby script intended to convert starred Google
Reader articles into something that can be imported into evernote.

This script basically converts JSON, obtained from [Google Takeout]
(https://www.google.com/takeout), to Evernote's .enex format.  This is a crude
script, intended to be used from the command-line.  There are also significant
issues -- see the list at the bottom.

This is all rather minimal: there is installatation or setup program, and
there is no friendly GUI.  Everything is from the command line, and the
instructions are minimal, as it's assumed that users know how to run ruby
scripts from the command line.

See the file, COPYING, for licensing information.


Requirements
------------

* Ruby 1.9 or later.

* You must have exported your Google Reader data via Google Takeout,
  downloaded, and extracted the data.  You need the file, "starred.json", as
  that is what you'll be feeding to this script.

  IMPORTANT NOTE: Google Takeout does not always properly export your data.
  In particular, you'll sometimes end up with a partial/truncated,
  "starred.json".  If this script gets errors, go back to Google Takeout and
  re-extract your Google Reader data (note: do not redownload the previous
  package, but instead have Google Takeout create a **new** download).

* Evernote, of course.


Usage
-----

    stars2evernote.rb [OPTIONS] FILE

FILE is the name of the file that contains the Google Reader starred .json
data; typically, "starred.json".

WIthout any options, the script will read the .json file and produce .enex, in
a file with the same name as the .json file, but with a .enex extension.  For
example, if you run:

    stars2evernote.rb starred.json

You'll end up with the converted data in "starred.enex", which you can then
import into evernote (this is for files that end with ".json" -- if you, for
example, use a data file called, "foo.dat", you'll end up with a converted
data file called, "foo.dat.enex").

OPTIONS can be:

<dl>
<dt><tt>-i</tt>, <tt>--info</tt></dt>
<dd>Read in the .json file and display information.  Currently, the only thing
printed is the number of notes.</dd>
<dt><tt>-l</tt>, <tt>--length=</tt><i>num</i></dt>
<dd>Only process <i>num</i> notes.</dd>
<dt><tt>-S</tt>, <tt>--sites</tt></dt>
<dd>Read notes and display a list of sites from which the notes
originated.</dd>
<dt><tt>-s</tt>, <tt>--start=</tt><i>offset</i></dt>
<dd>Start processing notes starting at note number <i>offset</i>.  Note that
the first note is at offset zero.</dd>
</dl>

Sometimes, the .enex file produced by this script cannot be imported by
evernote.  When this happens, it's caused by some unusual constructs in the
data for one of your starred articles.  To diagnose this, you need to
determine which of your starred articles is causing this, and that is why the
`--start` and `--length` command-line options exist: you need to use them to
perform a binary search to locate the offending article and send it to me
(assuming that you're comfortable with doing this).


Known Issues
------------

These may or may not be addressed:

* When importing, evernote imports all notes into a single notebook.
  There is no way to control this, as the .enex format does not have a
  way of controlling this.

* However, it may be possible to assign tags to the notes, based upon
  the feed from which the note originated.  This has not been
  implemented, though.

* Evernote titles have a maximum length of 255 (?) characters.  Any title
  longer than this will be silently truncated.

* Starred items typically have a short HTML description.  Any element
  disallowed by evernote will be silently removed -- in partcular, this
  includes **everything** between the opening and closing tag.
