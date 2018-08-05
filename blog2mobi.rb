#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'uri'
require 'tmpdir'

CALIBRE_CONVERT = "/Applications/calibre.app/Contents/MacOS/ebook-convert"

def ask_input(type, existing)
  print type + " [" + existing + "]: "
  input = $stdin.gets.strip
  if input != ""
    existing = input
  end

  return existing
end

def get_urls
  if not ARGV[0]
    print "Enter URL: "
    content = gets.strip
  else
    content = open(ARGV[0]).read
  end

  if content.include?("<a ")
    # HTML dump
    return content.scan(/href="(.*?)"/).map { |a| a[0] }
  else
    # Plain URL list
    return content.split("\n")
  end
end

class Counter
  def initialize
    @counter = 0
  end

  def get_next
    @counter += 1
    return @counter
  end
end

class WebToMobi
  def initialize(tmp, urls)
    @counter = Counter.new
    @toc = []
    @images = []
    @tmp = tmp
    @urls = urls

    @book_title = ""
    @book_author = ""
  end

  def process
    puts "Using #{@tmp} as temporary directory"

    download_pages()
    download_images()

    confirm_metadata()
    write_toc()

    call_calibre_convert("#{@tmp}/toc.html", "#{@book_title}.mobi")
  end

  def download_pages
    @urls.each do |url|
      download_page(url)
    end
  end

  def get_first(page, selectors)
    selectors.split(',').each do |s|
      elem = page.at_css(s.strip)
      if elem
        return elem
      end
    end
  end

  def download_page(url)
    outfile = "#{@counter.get_next}.html"
    puts "Downloading " + url + " as " + outfile

    page = Nokogiri::HTML(open(url))

    # Extract title
    title = get_first(page, '.entry-title, .post-title, title').text.strip
    @toc.push([outfile, title])
    puts "Title: " + title

    # Prefill book title from page title
    if @book_title == ""
      @book_title = title
    end
    if @book_author == ""
      @book_author = URI.parse(url).host
    end

    # Extract body
    body = get_first(page, '.entry-content, .post-body')

    # Get rid of "share this" box
    body.css('.sharedaddy, #comments').remove

    # Rewrite image URLs
    body.css('img').each do |img|
      # URI.join will correctly handle both relative and absolute URLs
      img_url = URI.join(url, img['src']).to_s
      # HACK: Calibre will figure it out
      ext = "jpg"

      local_src = "#{@counter.get_next}.#{ext}"
      @images.push([local_src, img_url])
      img['src'] = local_src
    end

    File.open("#{@tmp}/#{outfile}", "w") do |of|
      of.puts "<html><body>"
      if body.css('h1,h2').to_s.strip.empty?
        puts "Inserting title"
        of.puts "<h1>" + title + "</h1>"
      else
        puts "Inline Title: #{body.css('h1,h2,h3').to_s.strip}"
      end
      of.puts body.to_s
      of.puts "</body></html>"
    end
  end

  def download_images
    @images.each do |local_src, url|
      begin
        puts "Downloading image " + url + " as " + local_src
        File.write("#{@tmp}/#{local_src}", open(url).read)
      rescue OpenURI::HTTPError
        puts "Unable to download " + url
      rescue RuntimeError
        puts "Unable to download " + url
      end
    end
  end

  def confirm_metadata
    @book_title = ask_input("Title", @book_title)
    @book_author = ask_input("Author", @book_author)
  end

  def write_toc
    File.open("#{@tmp}/toc.html", "w") do |f|
      f.puts "<html><head><title>#{@book_title}</title><meta name=\"author\" content=\"#{@book_author}\"></head><body>"

      # We don't want to output this, it's just an index for Calibre to work on
      # Calibre will generate another ToC for us anyway
      f.puts "<div style=\"display:none\">"
      @toc.each do |entry|
        f.puts '<a href="%s">%s</a>' % entry
      end
      f.puts "</div></body></html>"
    end
  end

  def call_calibre_convert(input, output)
    output.gsub!(":", " ") # Hack to make filename more friendly
    system("\"#{CALIBRE_CONVERT}\" \"#{input}\" \"#{output}\" --filter-css font-family,color,margin-left,margin-right")
  end
end

# Run the main function
Dir.mktmpdir do |tmp|
  web_to_mobi = WebToMobi.new(tmp, get_urls())
  web_to_mobi.process()
end
