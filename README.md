stars2evernote.rb -- convert from Google Reader JSON to Evernote enex
=====================================================================

Version: 0.81, March 23, 2013

Stars2evernote.rb is a kludgy ruby script intended to convert starred Google
Reader articles into something that can be imported into the Evernote desktop
client.

This script basically converts the starred articles in JSON form, obtained
from [Google Takeout](https://www.google.com/takeout), to Evernote's .enex
format.  You then import this .enex file into the desktop client.  By doing
this, the data import is reasonably fast, and there are no API networking
issues to worry about.  The client might take a long time to synchronize,
though.

**IMPORTANT NOTE**: This script handles most, but not all starred articles.
In particular, starred articles whose blurbs include tables will likely import
but **NOT** synchronize (Evernote will forever banish such notes to the
"Unsynced Notes" notebook).  Hopefully, you'll have few, if any, of these
notes, which will have to be manually imported (you click on the article URL
and manually re-clip the note into Evernote, as a new note).  Also note that
the table may appear to be properly rendered the first time you view the
Evenote note, but will probably be deleted by Evernote once you stop viewing
the note (after which exporting the now "fixed" unsynchronizable note and
re-importing it will result in something that will synchronize, but will be
missing the table and anything else that Evernote does not like).

This is a crude script, intended to be used from the command-line.  There are
also significant issues -- see the list at the bottom.  In particular, this
script is not well-tested.

This is all rather minimal: there is **NO** installatation or setup program,
and there is no friendly GUI.  Everything is from the command line, and the
instructions are minimal, as it's assumed that users know how to run ruby
scripts from the command line.

See the file, COPYING, for licensing information.


Requirements
------------

* Ruby 1.9 or later.

* You must have exported your Google Reader data via [Google
  Takeout](https://www.google.com/takeout), downloaded, and extracted the
  data.  You need the file, "starred.json", as that is what you'll be feeding
  to this script.

  IMPORTANT NOTE: Google Takeout does not always properly export your data.
  In particular, you'll sometimes end up with a partial/truncated,
  "starred.json".  If this script gets errors, try going back to Google
  Takeout and re-extracting your Google Reader data (note: do not redownload
  the previous package, but instead have Google Takeout create a **new**
  download).

* You need the Evernote desktop client.  (Currently only tested with the
  windows desktop client, version "4.6.4.8136 (268644) Public".)


Usage
-----

    stars2evernote.rb [OPTIONS] FILE

FILE is the name of the file that contains the Google Reader starred .json
data; typically, ``starred.json".

WIthout any options, the script will read the .json file and produce .enex, in
a file with the same name as the .json file, but with a .enex extension.  For
example, if you run:

    stars2evernote.rb starred.json

You'll end up with the converted data in "starred.enex", which you can then
import into Evernote (this is for files that end with ".json" -- if you, for
example, use a data file called, "foo.dat", you'll end up with a converted
data file called, "foo.dat.enex").

OPTIONS can be:

<dl>
<dt><tt>--debug</tt></dt>
<dd>Enable debug messages.  Currently doesn't do much.</dd>
<dt><tt>--dump</tt></dt>
<dd>Dump out parsed json data to stdout.  No conversion is done.  Mainly used
for reporting problem notes that aren't converted properly, and are causing
Evernote to refuse to read them.</dd>
<dt><tt>-f</tt>, <tt>--feed=</tt><i>feed-name</i></dt>
<dd>Only process notes that came from feed, "<i>feed-name</i>".  The feed name
must be exactly one of the feeds displayed by the `--list-feeds` option.  This
option can only be specified once.  By extracting a single feed, you can use
this to import your starred feeds into separate notebooks.</dd>
<dt><tt>-i</tt>, <tt>--info</tt></dt>
<dd>Read in the .json file and display information.  Currently, the only thing
printed is the number of starred notes in the .json file.  No conversion is
done.</dd>
<dt><tt>-l</tt>, <tt>--length=</tt><i>num</i></dt>
<dd>Only process <i>num</i> notes.</dd>
<dt><tt>-L</tt>, <tt>--list-feeds</tt></dt>
<dd>Read notes and display (to stdout) a list of feeds from which the notes
originated.  No conversion is done.</dd>
<dt><tt>-s</tt>, <tt>--start=</tt><i>offset</i></dt>
<dd>Start processing notes starting at note number <i>offset</i>.  Note that
the first note is at offset zero.</dd>
</dl>

Sometimes, the .enex file produced by this script cannot be imported by
Evernote.  When this happens, it's caused by some unusual constructs in the
data for one of your starred articles.  To diagnose this, you need to
determine which of your starred articles is causing this, and that is why the
`--start` and `--length` command-line options exist: you need to use them to
perform a binary search to locate the offending article (assuming that you're
comfortable with showing others your note).  Once you know what note is
causing problems, you can then use the `--dump` option to dump out its raw
parsed data, for reporting in a bug report.


Examples
--------

Note: in the following, "note numbering" refers to the order in which notes
appear in Google's .json file.  Numbering starts at zero, and so the first
note in the file is note number 0.

Convert all notes (the output is placed into `starred.enex`):

    stars2evernote.rb starred.json

Convert the first 500 notes:

    stars2evernote.rb --length 500 starred.json

Convert starting at note number 500 (numbering starts at 0, and so the first
500 are numbered 0-499 -- note number 500 is the 501st note):

    stars2evernote.rb --start 500 starred.json

Convert notes numbered 500-999 (inclusive):

    stars2evernote.rb --start 500 --length 500 starred.json

Display a list of all feeds:

    stars2evernote.rb --list-feeds starred.json

Display a list of feeds in notes number 10-19:

    stars2evernote.rb --list-feeds --start 10 -length 10 starred.json

Only convert notes in the feed named, "Ye Old Google Times" (use
`--list-feeds` to see a list of feed names):

    stars2evernote.rb --feed="Ye Old Google Times" starred.json



Known Issues/Quirks
-------------------

Note that issues may or may not be addressed:

* This script hasn't been well-tested.  Beware.  For testing, you'll probably
  want to import your notes into an unsynchronized (local) notebook.  Once
  you're satisfied, you can either move the notes into a synchronized
  notebook, or just re-import the notes into a synchronized one.

* Notes that contain tables may appear to import, but will often not
  synchronize, because Evernote requires that all tables have a "height"
  attribute, and many do not.  Notes with these tables will import but not
  synchronize.  When the first synchronization attempt is made, Evernote will
  move these notes to the "Unsynced Notes" notebook, and mark them as being
  **forever** unsynchronizable (no amount of editing the unsynchronizable note
  will make it synchronizable).

  Unfortunately, there's no easy way for this to be fixed.  Hopefully, you
  won't have very many of these, and so you can probably click on the URL and
  create a new note in Evernote from the web page.

* **IMPORTANT NOTE**: the very first time you view an unsynchronizable note,
  the note might appear to render correctly.  However, viewing another note
  and then re-viewing this unsynchronizable note will typically result in the
  problematic parts being **deleted**, resulting in the loss of information.
  If you then export and re-import this note, the note will then be
  synchronizable (because Evernote deleted the parts that it did not like
  after you viewed the note, but before you re-exported it).

* When importing, Evernote imports all notes into a single notebook.
  There is no way to control this, as the .enex format does not have a
  way of controlling this.

  However, because you can extract the notes for a single feed using the
  `--feed` option (see above), you have a crude ability to put feeds into
  different notebooks.  Unix/Mac/cygwin users can write a shell script that
  extracts all feeds into different files; when importing, each of these will
  then be put into a separate notebook.

* User tags in starred articles aren't migrated.  This script currently has no
  support for adding Evernote tags.  Perhaps a later version will support them.

  Perhaps there should also be a way of assigning a tag based upon the feed
  name?

* THe RSS feed name and main site URL (if available) are prepended to the
  note.

* Evernote titles have a maximum length of 255 (?) characters.  Any title
  longer than this will be silently truncated.

* Starred items typically have a short HTML description.  Any element in this
  description disallowed by Evernote will be **silently removed** -- in
  partcular, this includes **everything** between the opening and closing tag.

  **IMPORTANT NOTE**: Embedded youtube videos often use <iframe> elements,
  which are disallowed by evernote and are thus removed by this script.  This
  will result in the embedded youtube video being removed from the note,
  without anything replacing it.

* Note that after conversion and importing, any "images" in a converted note
  is a reference to a remote server image.  However, after you view the
  imported note in the Evernote desktop client, Evernote seems to convert the
  remote image reference into a local copy (however, I've seen remote
  advertisement image references left untouched).
