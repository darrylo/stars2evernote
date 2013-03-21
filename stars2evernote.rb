#! /usr/bin/env ruby
###############################################################################
#
#    stars2evernote -- Convert a list of starred google reader articles to an
#        evernote .enex file.  The list of starred google reader articles is
#        taken from a google takeout .json file from a user's google reader
#        data.
#
#    Copyright (C) 2013 Darryl Okahata
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
###############################################################################
# Version 0.8, March 19, 2013
###############################################################################

require 'json'
require 'pp'

# Load local translator, if any
begin
  require "stars2evernote-local.rb"
rescue LoadError
  module Stars2EvernoteLocal
    def local_translate
    end
  end
end


# This class is used to hold one parsed starred note.  Only the basics are
# stored, here.
class ReaderItem
  private

  include Stars2EvernoteLocal

  # TODO?
  # A number of attributes are also disallowed from the supported XHTML
  # elements:
  #
  #     id
  #     class
  #     onclick
  #     ondblclick
  #     on*
  #     accesskey
  #     data
  #     dynsrc
  #     tabindex

  # ENEX disallows these elements
  @@bad_regexp = 
    Regexp.new("<(" + [
                       "applet",
                       "audio",
                       "base",
                       "basefont",
                       "bgsound",
                       "blink",
                       "body",
                       "button",
                       "dir",
                       "embed",
                       "fieldset",
                       "form",
                       "frame",
                       "frameset",
                       "head",
                       "html",
                       "iframe",
                       "ilayer",
                       "input",
                       "isindex",
                       "label",
                       "layer,",
                       "legend",
                       "link",
                       "marquee",
                       "menu",
                       "meta",
                       "noframes",
                       "noscript",
                       "object",
                       "optgroup",
                       "option",
                       "param",
                       "plaintext",
                       "script",
                       "select",
                       "style",
                       "textarea",
                       "xml"
                      ].join('|') + ")\\b")

  # This regexp is used to strip out elements and their matching closing tags.
  @@element = Regexp.new("^(.*)<([^ \t>]+)[^>]*>(.*?)</\\2[^>]*>(.*)$",
                         Regexp::MULTILINE)

  @@close_elements_basic = Regexp.new("^(.*)<(hr|br)>(.*)$",
                                      Regexp::MULTILINE)
  @@close_elements = Regexp.new("^(.*)<(img|hr|br)(\\s+[^>]*[^/])>(.*)$", 
                                Regexp::MULTILINE)
  @@img_fixups = Regexp.new("^(.*<img\\s+.*)\\bismap\\b(\\s*[^=][^>]*>.*)$", 
                            Regexp::MULTILINE)

  @@unclosed_open = Regexp.new("^(.*)<(p)(\\b[^>]*)>(.*)$",
                               Regexp::MULTILINE)

  @@javascript_link = Regexp.new("^(.*)<a\\s[^>]*\\bhref\\s*=\\s*\"javascript:[^\">]+\"[^>]*>(.*?)</a>(.*)$",
                                 Regexp::MULTILINE)

  @@debug = false

  # Convert key characters to HTML character encodings:
  def encode(text)
    text.gsub!(/&(?!amp;)/, "&amp;")
    text.gsub!("<", "&lt;")
    text.gsub!(">", "&gt;")
    return text
  end

  # Cheesy func to prettify and clean up text for use as a description or tag.
  def unencode(text)
    text.gsub!("&#39;", "'")
    text.gsub!("&quot;", '"')
    text.gsub!("&amp;", "&")	# Need this because encode() puts it back, if
				# used
    return text
  end

  # This is so horribly grotesque, because it utterly ignores the
  # nesting of any intermediate elements ...
  def gobble_unclosed_open(content)
    #print "\nContent before: '#{content}'\n\n"

    processed = ""
    content_to_process = content
    # Find a candidate unclosed element ...
    while m = @@unclosed_open.match(content_to_process)
      # Tear it apart ...
      preamble = m[1]
      element = m[2]
      element_args = m[3]
      rest = m[4]

      processed << preamble

      # Look for a closing element ...
      next_elem = Regexp.new("^(.*)(<(/)?#{element}\\b[^>]*>)(.*)$",
                             Regexp::MULTILINE)
      if m2 = next_elem.match(rest) then
        #
        # We seem to have found something.  Hopefully, it's the right
        # one, but we have absolutely no way of knowing, since we're
        # not doing it right.
        #
        # Now put the line back together, but possibly stripping out
        # any unclosed elements ...
        #
        processed << "<" + element + element_args + ">"
        if m2[3].empty? then
          # opening element
          processed << m2[1]
          processed << gobble_unclosed_open(m2[2] + m2[4])
          content_to_process = ""
          break
        else
          # closing element
          processed << m2[1] << m2[2]
          content_to_process = m2[4]
        end
      else
        # No closing element -- kill the opening element
        content = preamble + rest
        content_to_process = ""
        break
      end
    end
    processed << content_to_process
    content = processed

    #print "\nContent after: '#{content}'\n\n"
    return content
  end

  def fixup_content(content)
    #
    # Convert basic elements like <hr> or <br> into <hr/> and <br/>
    #
    while m = @@close_elements_basic.match(content)
      content = m[1] + "<#{m[2]}/>" +m[3]
    end

    #
    # Convert more complex elements with attributes.
    #
    # Example: <img> get converted into <img ... />
    # Hopefully, this should be safe, with no sites would use it
    # like <img ... ></img>
    #
    while m = @@close_elements.match(content)
      content = m[1] + "<#{m[2]}#{m[3]}/>" +m[4]
    end

    while m = @@img_fixups.match(content)
      # strip out lone ismap attributes, because Evernote does not like 
      # then without a value
      content = m[1] + m[2]
    end

    # Kill "javascript:void" links, as Evernote doesn't like them
    while m = @@javascript_link.match(content)
      content = m[1] + m[2] + m[3]
    end

    #
    # Ugh, this has got to be one of the nastier attempts at handling
    # unclosed elements (just strip them out).  We really need a
    # proper parser for this, but I'm just going to use the a**l probe
    # method instead.
    #
    content = gobble_unclosed_open(content)

    return content
  end

  public

  attr_reader :id, :valid, :title, :content, :source_url, :created, :modified

  # Turn debugging on/off
  def ReaderItem.set_debug(debug)
    @@debug = debug
  end

  def initialize(id, title, content, source_url, created, modified, site, site_url)
    @id = id
    @title = title
    @content = fixup_content(content)
    @source_url = encode(source_url)
    @created = created
    @modified = modified
    @site = site
    @site_url = site_url

    while m = @@element.match(@title)
      @title = m[1] + m[3] + m[4]
    end

    @title = unencode(@title)
    @title.gsub!(/[ \t]{2,}/, " ")

    if @@debug and /&/.match(@title) then
      STDERR.print "Malformed title @#{@id}: '#{@title}'\n"
    end

    @title = encode(@title)

    if @title.size > 255 then
      @title = @title[0, 255]
    end

    @site = encode(@site)
    @site.gsub!("\n", "")
    @site.gsub!(/[ \t]{2,}/, " ")

    added = false
    preamble = ""
    if @site and not @site.empty? then
      preamble = preamble + "Source: #{@site}<br/>\n"
      added = true
    end
    if @site_url and not @site_url.empty? then
      preamble = preamble + "Main Source URL: <a href=\"#{encode(@site_url)}\">#{encode(@site_url)}</a><br/>\n"
      added = true
    end
    if added then
      @content = preamble + "<hr/><br/>\n" + @content
    end

    @valid = true
    if m = @@bad_regexp.match(@content) then
      element = m[1]
      fixer = Regexp.new("^(.*)<#{element}[^>]*>.*?</#{element}[^>]*>(.*)$", Regexp::MULTILINE)
      #STDERR.print fixer.to_s, "\n"
      while m = fixer.match(@content)
        @content = m[1] + m[2]
      end
      if m = @@bad_regexp.match(@content) then
        STDERR.print "Skipping note ###{@id}: Bad HTML element (#{m[1]}) found in \"#{@title}\"\n"
        @valid = false
      end
    end

    local_translate
  end

end


class TranslateReaderStarredToEnex
  private

  def get_time_val(val)
    if val.nil? or (val.class == String and val.empty?) then
      val = Time.now
    elsif val.class == String or val.class == Bignum then
      val = Time.at(val)
    elsif val.class != Time then
      raise "Huh? (#{val.class.to_s})"
    end
    val = val.strftime("%Y%m%dT%H%M%SZ")
    return val
  end

  def read_json(file)
    @data = JSON.parse(File.open(file, "r:utf-8").read())
    @translated_items = []
    true
  end

  def translate(item, start_offset = 0, length = -1, only_feed = nil)

    title = item['title']
    if title.nil? then
      STDERR.print "NO TITLE: #{item.to_s}\n"
      title = ""
    end
    title.strip!

    summary = item['summary']
    if summary.nil? then
      summary = item['content']
    end
    if summary then
      summary = summary['content']
    else
      summary = ""
    end
    summary.strip!

    if true then
      created = get_time_val(item['published'])
      modified = get_time_val(item['updated'])
    else
      created = item['timestampUsec']
      if created then
        created = created.to_i / 1000000
      else
        created = Time.now
      end
      modified = Time.now
    end

    url = ""
    alternate = item['canonical']
    if alternate.nil? then
      alternate = item['alternate']
    end
    if alternate then
      alternate = alternate[0]
      if alternate then
        url = alternate['href']
        if not url or (url.class == String and url.empty?) then
          STDERR.print "No URL found in \"#{title}\" (type: '#{alternate["type"]}')\n"
        end
      end
    end
    url.strip!

    site = "UNKNOWN"
    site_url = ""
    origin = item['origin']
    if origin then
      if origin["title"] then
        site = origin["title"]
      end
      if origin["htmlUrl"] then
        site_url = origin["htmlUrl"]
      end
    end
    site.strip!
    site_url.strip!

    if ((start_offset >= 0) && (@read_count < start_offset)) || 
        ((length > 0) && (@read_count >= start_offset + length)) ||
        (only_feed && only_feed != site) then
      @read_count = @read_count + 1
      return
    end

    @translated_items << ReaderItem.new(@read_count, title, summary, url,
                                        created, modified, site, site_url)

    @sites[site] = true

    @read_count = @read_count + 1
  end

  def print_header(outstream)
    outstream.print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE en-export SYSTEM \"http://xml.evernote.com/pub/evernote-export.dtd\">
<en-export export-date=\"#{get_time_val(nil)}\" application=\"stars2evernote\" version=\"4.x\">
"
  end

  def print_trailer(outstream)
    outstream.print "</en-export>\n"
  end


  public
  
  attr_reader :data

  def initialize
    @json = nil
    @translated_items = []
    @read_count = 0
    @sites = {}
  end

  def read_and_translate(file, start_offset = 0, length = -1, only_feed = nil)
    read_json(file)
    data["items"].each { |item|
      translate(item, start_offset, length, only_feed)
    }
  end

  def get_sites
    return @sites.keys
  end

  def num_items
    return (@translated_items.length)
  end

  def print_translated(outstream)
    print_header(outstream)
    @translated_items.each { |item|
      if not item.valid then
        # skip invalid items
        if @@debug then
          STDERR.print "Skipping invalid item id###{item.id}\n"
        end
        next
      end

      outstream.print "<note>\n"
      outstream.print "<title>", item.title, "</title>\n"

      outstream.print '<content>
<![CDATA[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>
'
      outstream.print item.content, "\n"
      outstream.print '</en-note>]]>
</content>
'

      outstream.print "<created>", item.created, "</created>\n"
      outstream.print "<updated>", item.modified, "</updated>\n"

      outstream.print "<note-attributes>\n"
      outstream.print "<source>", "stars2evernote", "</source>\n"
      if item.source_url and not item.source_url.empty? then
        outstream.print "<source-url>", item.source_url, "</source-url>\n"
      end

      outstream.print "</note-attributes>\n"

      outstream.print "</note>\n"
    }
    print_trailer(outstream)
  end

  def dump
    @translated_items.each { |item|
      if not item.valid then
        # skip invalid items
        if @@debug then
          STDERR.print "Skipping invalid item id###{item.id}\n"
        end
        next
      end
      pp item
    }
  end
end


if $0 == __FILE__ then

  require 'getoptlong'

  start = 0
  length = -1
  mode = 0
  only_feed = nil

  opts = GetoptLong.new(
                        [ "--debug", GetoptLong::NO_ARGUMENT ],
                        [ "--dump", GetoptLong::NO_ARGUMENT ],
                        [ "--feed", "-f", GetoptLong::REQUIRED_ARGUMENT ],
                        [ "--start", "-s", GetoptLong::REQUIRED_ARGUMENT ],
                        [ "--length", "-l", GetoptLong::REQUIRED_ARGUMENT ],
                        [ "--list-feeds", "-L", GetoptLong::NO_ARGUMENT ],
                        [ "--info", "-i", GetoptLong::NO_ARGUMENT ],
                        )

  opts.each { |option, value|
    if option == "--start" then
      start = value.to_i
    elsif option == "--length" then
      length = value.to_i
    elsif option == "--feed" then
      only_feed = value.strip
      if only_feed.empty? then
        only_feed = nil
      end
    elsif option == "--debug" then
      ReaderItem.set_debug(true)
    elsif option == "--info" then
      mode = 1
    elsif option == "--list-feeds" then
      mode = 2
    elsif option == "--dump" then
      mode = 3
    end
  }


  infile = ARGV[0]
  if not File.exists?(infile) then
    STDERR.print "ERROR: \"#{infile}\": does not exist\n"
    exit 1
  end

  a = TranslateReaderStarredToEnex.new()
  begin
    a.read_and_translate(infile, start, length, only_feed)
  rescue JSON::ParserError => e
    STDERR.print "ERROR parsing file, \"#{infile}\".\n"
    STDERR.print "Occasionally, the Google Takeout mechanism for Google Reader silently
fails, and does not produce a complete .json file for the starred articles,
causing parsing failures.  To check, go back to Google Takeout and see if the
estimated size for the Google Reader data is close to the size of the .json
file.  If it's not, that difference is likely due to Google Takeout failing,
and not giving you all of the starred article information.  Go back to Google
Takeout and try re-extracting and re-downloading a new set of Google Reader
data.  Do not simply re-download the previous data, but instead create a new
set."
    exit 1
  end

  if mode == 0 then
    # Convert from .json to .enex
    outfile = File.basename(infile, ".json") + ".enex"
    a.print_translated(File.open(outfile, "w"))
  elsif mode == 1 then
    # Just print some info about the notes
    print "Total number of items = #{a.num_items}\n"
  elsif mode == 2 then
    # Print out a list of site names.
    a.get_sites.sort.each { |site|
      print site, "\n"
    }
  elsif mode == 3 then
    # dump data
    a.dump
  else
    raise
  end

end

