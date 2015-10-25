# blog2mobi.rb

A simple script to download a WordPress blog post with images and convert
to mobi for reading on an E-Reader such as a Kindle.

    Usage: blog2mobi.rb urls.txt

       where urls.txt contains a list newline-separated URLs to download. The
       content of all URLs will be combined into one mobi. Alternatively, an
	   extract of an HTML page and be provided and URLs will be automatically
	   extracted from the page.
