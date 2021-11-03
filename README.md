# AP RSS processor, written in Ruby

This is an old Ruby script that attempted to duplicate an old AP wire newsfeed, using a newer AP RSS feed.  It likely doesn't work anymore, and I have no way to test it.  If you dig through the history you can probably find an old username and password, but I feel reasonably certain that doesn't work anymore, either.  If it does and you're contacting me to get rid of it, I'll be more than happy to scrub the history on the file.

The idea was that this tried to emulate an old setup, one where a specialized piece of software running on a MacOS Classic machine (I forget the name of the software) would dump stories into folders.  Then the Associated Press replaced their dedicated satellite service with an RSS feed, and a specialized feed reader.  At the time I was working at a newspaper satellite office that didn't have equipment to spare, a staff that was highly disgruntled at having to log in to a website, and a dogged determination to learn something about Ruby.  Thus this was born; the script would scrape the feeds every five minutes, download any new stories, and convert them to MacRoman encoding and save them to a folder that was shared on the network via Netatalk.

The script isn't guaranteed to work and hasn't been tried by me since 2011.
