####################################################
# �����: Vertigo
# ������: 2.9
# ��������: C����� ������ ��������� ������� � ��������� ���� ��������.
# �������: !�������
####################################################

namespace eval ::feed {

	# ������� �������� �������� �� ���������:
	variable lines 1
	# ������������ ���-�� ��������� ��������:
	variable maxlines 3
	# ������������ ����� �������:
	variable maxlength 200
	# ������ ������ �������� �� ���������:
	#variable defformat "\00314\[ %name% \] \00307:: \00304 ����: \00314%date% \00304 �������: \00314%title% \00307:: \00304 ������: \00314%descr% \00304 ��������: \037\00314%link%\017"
	variable defformat "\002\00303 %name% \002\00301,00%title% \003\00303 %descr% \00307%link%"
	# �������� ����-�������� ����? [0/1]
	variable autofeeds 1
	# ����� ������� ����� ��������� ���������� ����? [1-59]
	variable freq "10"
	# ��� ����� �������/��������� �����?
	variable autoflags "n|n"
	# ������� ��������� ��������? [1-5]
	variable checklines 1
	# ���� � ���� ��������:
	variable datafile {data/feeds.dat}
	# ������� � ��������:
	variable timeout "20"
	# �������� �����?
	variable debug 0
	# ����-�����:
	variable useragent {Opera/9.80 (Windows NT 6.1; U; ru) Presto/2.9.168 Version/11.50}
	# ������������ ���-�� �������� � ���� ��� ����� �����:
	variable maxnews "1"

bind pub - $::gprefix(1)feed [namespace current]::pub
bind pub - $::gprefix(1)������� [namespace current]::pub
bind msg - $::gprefix(1)feed [namespace current]::msg
bind msg - $::gprefix(1)������� [namespace current]::msg
bind pub o|o $::gprefix(1)feeds [namespace current]::feedlist
bind pub o|o $::gprefix(1)������� [namespace current]::feedlist
bind time - {* * * * *} [namespace current]::timecheck

variable chflag no[namespace tail [namespace current]]
variable redirs 0; setudef flag $chflag
if {![file exists $datafile]} {set f [open $datafile w+]; close $f; unset -nocomplain f}

proc msg {nick uhost hand text} {main $nick $uhost $hand $nick $text}
proc pub {nick uhost hand chan text} {variable chflag; if {[channel get $chan $chflag]} {return}; main $nick $uhost $hand $chan $text}

proc feedlist {nick uhost hand chan text} {
variable datafile; variable chflag
if {[channel get $chan $chflag]} {return}
if {[string is space $text]} {set text $chan}
set f [open $datafile r]
set fdata [lrange [split [read $f] \n] 0 end-1]
close $f
if {![llength $fdata]} {putserv "NOTICE $nick :� ���� ��� �� ����� �����."; return 0}
if {[string index $text 0] == "#" } {
if {[validchan $text]} {set ch $text} else {putserv "NOTICE $nick :� �� ��������� ����� $text."; return}
} elseif {$text == "all" || $text == "���"} {set ch "*"} elseif {$text == "list" || $text == "������"} {
set tmp [list]
foreach _ $fdata {
if {$chan in [lindex $_ 2]} {
foreach str [lindex $_ 3] {
if {[llength $str] == "2"} {lappend tmp "[lindex $str 1] [list [lindex $str 0]]"}
}
}
}
if {![llength $tmp]} {
putserv "NOTICE $nick :� ���������, ��� �������� �������� ��� ������� ������."
unset -nocomplain fdata
return
}
set tmp [lsort -real -decreasing -index 0 $tmp]
putserv "NOTICE $nick :*** ��������� ������� ��� ������ ${chan}:"
foreach _ [lrange $tmp 0 4] {
::ccs::put_msgdest -type notice $nick "$::gcolor(4)[clock format [lindex $_ 0] -format "%d.%m-%H:%M"]\017 [lindex $_ 1]"
}
unset -nocomplain fdata tmp
return
}
if {$ch != "*"} {putserv "NOTICE $nick :*** ������ ���� ��� ������ ${ch}:"} {putserv "NOTICE $nick :*** ������ ����:"}
set i 0
putserv "NOTICE $nick :.---\[#\] -|- \[�����\] -|- \[������\] -|- \[������\] -|- \[���������\] -|- \[��������\]---"
foreach _ $fdata {
if {[string match -nocase "$ch" [join [lindex $_ 2]]] || [string match -nocase "$ch *" [join [lindex $_ 2]]] || [string match -nocase "* $ch" [join [lindex $_ 2]]] || [string match -nocase "* $ch *" [join [lindex $_ 2]]]} {
putserv "NOTICE $nick :|���$::gcolor(4)[incr i].\017 -|- $::gcolor(12)\037[lindex $_ 0]\017 -|- [join [lindex $_ 2] ", "] -|- [lindex $_ 1]\017 -|- [clock format [lindex $_ 4] -format "%d.%m.%Y / %H:%M:%S"] -|- [llength [lindex $_ 3]]"
}
}
putserv "NOTICE $nick :`---\[ ����� ������ \]---"
return
}
	
proc timecheck {mins hours days month years} {
variable datafile; variable timeout
variable debug; variable freq
if {[expr [scan $mins %d] % $freq] eq "0"} {
if {$debug} {putlog "\[feed\] Info: timecheck running..."}
set f [open $datafile r]
set fdata [lrange [split [read $f] \n] 0 end-1]
close $f
if {![llength $fdata]} {return}
foreach _ $fdata {
set url [lindex $_ 0]
set format [lindex $_ 1]
set chan [lindex $_ 2]
set string [lindex $_ 3]
set i 0
foreach chan_ $chan {
if {![validchan $chan_] || ![botonchan $chan_] || [channel get $chan_ nofeed]} {
incr i
if {$debug} {putlog "\[feed\] ERROR: timecheck: Invalid channel ${chan_}!"}
continue
}
}
if {$i == [llength $chan]} {
if {$debug} {putlog "\[feed\] ERROR: timecheck: No channels for URL ${url}!!!"}
continue
}
variable useragent
::http::config -urlencoding utf-8 -useragent $useragent
if {[catch {set token [::http::geturl $url -timeout [expr $timeout * 1000] -binary 1 -protocol 1.0 -headers [list "Accept-Encoding" "None"] -command [list [namespace current]::data $chan $url 1 $format 1 $string ""]]} err]} {
if {$debug} {putlog "\[feed\] ERROR: timecheck: Unable connect to '$url' ($err)"}
continue
}
}
unset -nocomplain fdata f
}
}

proc main {nick uhost hand chan text} {
variable timeout; variable lines
variable defformat; variable maxlines
variable autofeeds; variable autoflags
if {[string is space $text]} {
if {[matchattr $hand n|n $chan]} {
putserv "NOTICE $nick :������: $::lastbind <URL> \[�auto|-remove\] \[����� ��������\] \[������ ������\] - ����� ��������� ������� � RSS/Atom �����."
putserv "NOTICE $nick :\002�auto\002 - ��������/��������� ������������ ���������� �� ������. \002-remove\002 - ������� �� ������ �����. ����� �������� ���������� ���������� ��������� ��������� �� �����/������ (�� ��������� $lines, �������� $maxlines)\; ������ ������� ���������� ���������� ������ ������ ������ (�� ��������� - $defformat\017). ��������� ����: %date%, %descr%, %link%, %name%, %title%."
putserv "NOTICE $nick :��� ��������� ������ �������� ����������� �������: $::gprefix(1)������� \[#�����/���|������\]"
} else {
putserv "NOTICE $nick :������: $::lastbind <URL> \[����� ��������\] - ����� ��������� ������� � RSS/Atom �����. ����� �������� ���������� ���������� ��������� ��������� �� �����/������ (�� ��������� $lines, �������� $maxlines)."
}
return
}
if {[string match -nocase "*+auto*" $text]} {set auto "1"; regsub -- {\+auto\s?} $text "" text
} elseif {[string match -nocase "*-auto*" $text]} {set auto "-1"; regsub -- {\-auto\s?} $text "" text
} elseif {[string match -nocase "*-remove*" $text]} {set auto "-2"; regsub -- {\-remove\s?} $text "" text} else {set auto "0"}
if {$auto == "-2" && ![matchattr $hand n]} {putserv "NOTICE $nick :� ��� ��� ����������� ���� ��� �������� �����."; return} 
if {$auto != "0" && ![matchattr $hand $autoflags $chan]} {putserv "NOTICE $nick :� ��� ��� ����������� ���� ��� ��������� ������."; set auto 0}
if {$auto != "0" && $autofeeds == "0"} {putserv "NOTICE $nick :�������������� ���������� ���� ���������..."; set auto 0}
set text [string trim [regsub -all -- {\s+} $text "\x20"]]
set text [split $text]
set url [lindex $text 0]
if {[string range $url 0 6] ne "http://" && [string range $url 0 7] ne "https://"} {set url "http://$url"}
if {[string is digit [lindex $text 1]]} {
set num [lindex $text 1]
if {[lrange $text 2 end] ne ""} {set format [join [lrange $text 2 end]]} else {set format $defformat}
} else {
set num $lines
if {[lrange $text 1 end] ne ""} {set format [join [lrange $text 1 end]]} else {set format $defformat}
}
if {$auto eq "-1" || $auto == "-2"} {
variable datafile
set f [open $datafile r]
set fdata [lrange [split [read $f] \n] 0 end-1]
close $f
if {[string is space [set indx [lsearch -all -nocase -index 0 $fdata "$url"]]]} {
putserv "NOTICE $nick :���� ����� ��� � ������. ����������� \002$::gprefix(1)�������\002 ��� ��������� ������."
set auto 0
unset -nocomplain fdata f indx
return 0
} else {
if {[llength $fdata] eq "1" && [llength [join [lindex $fdata $indx 2]]] eq "1"} {
set f [open $datafile w+]
close $f
putserv "PRIVMSG $chan :����� '$url' ������� �� ������ �������."
return
} else {
if {$auto == "-2"} {
set fdata_ [lreplace $fdata $indx $indx]
set f [open $datafile w]
puts $f [join $fdata_ \n]
flush $f
close $f
putserv "PRIVMSG $chan :����� '$url' ������� �� ������ �������."
return
}
set chans [join [lindex $fdata $indx 2]]
if {$chan ni $chans} {
putserv "NOTICE $nick :�� ������ $chan ����� ����� ���!"
unset -nocomplain fdata
return
} else {
set tmp [list]
foreach _ $chans {
if {$chan == $_} {continue}
lappend tmp $_
}
if {![llength $tmp]} {
set fdata_ [lreplace $fdata $indx $indx]
set f [open $datafile w]
puts $f [join $fdata_ \n]
flush $f
close $f
putserv "PRIVMSG $chan :����� '$url' ������� �� ������ �������."
} else {
set line [lindex $fdata $indx]
lassign $line url format chan_ string updated
set fdata_ [lreplace $fdata $indx $indx [list $url $format [join $tmp] $string $updated]]
set f [open $datafile w]
puts $f [join $fdata_ \n]
flush $f
close $f
putserv "PRIVMSG $chan :��� ������ $chan ����� '$url' ������� �������."
}
unset -nocomplain fdata fdata_ f indx
return 0
}
}
}
}
variable useragent
if {[string is space $num]} {set num $lines}
if {$num > $maxlines} {set num $maxlines}
::http::config -useragent $useragent -urlencoding utf-8
if {[catch {set token [::http::geturl $url -timeout [expr $timeout * 1000] -binary 1 -protocol 1.0 -headers [list "Accept-Encoding" "None"] -command [list [namespace current]::data $chan $url $num $format 0 "" $auto]]} err]} {
putserv "NOTICE $nick :�� ������� ������������ � '$url' ($err)"
return
}
}
	
proc data {chan url num format {timecheck 0} {string ""} {auto ""} token} {
variable redirs; variable timeout
variable debug; variable maxlength
set status [::http::status $token]
set code [::http::ncode $token]
if {$status eq "timeout"} {
if {$timecheck eq "0"} {putserv "PRIVMSG $chan :����-��� ����������� � '$url'"}
::http::cleanup $token
return
}
if {$status eq "error"} {
if {$timecheck eq "0"} {putserv "PRIVMSG $chan :������ ��� ����������� � '$url'. ([::http::error $token])"}
::http::cleanup $token
return
}
if {$code ne "200" && [string range $code 0 1] ne "30"} {
if {[string is space [set Code [::http::code $token]]]} {set Code "unknown"}
if {![string is space [::http::error $token]]} {append Code ", [::http::error $token]"}
if {$timecheck eq "0"} {putserv "PRIVMSG $chan :������ (HTTP-���: $Code) -> '$url'"}
::http::cleanup $token
return
}
array set meta [::http::meta $token]
if {[info exists meta(Location)] && [string index $code 0] eq "3" && $redirs <= 3} {
incr redirs
::http::cleanup $token
if {[string index $meta(Location) 0] eq "/"} {set meta(Location) "$url$meta(Location)"}
if {[catch {set token [::http::geturl $meta(Location) -protocol 1.0 -headers [list "Accept-Encoding" "None"] -timeout [expr $timeout * 1000] -binary 1 -command [list [namespace current]::data $chan $url $num $format $timecheck $string $auto]]} err]} {
if {$timecheck eq "0"} {putserv "PRIVMSG $chan :�� ������� ������������ � '$url' ($err)"}
}
return
}
set redirs 0
if {![info exists meta(Content-Type)]} {set type "unknown"; set charset ""} else {
set type $meta(Content-Type)
set charset [lindex [regexp -inline -nocase -- {charset=(.*?)$} $type] 1]
}
regsub -- {;.*$} $type "" type
set data [encoding convertfrom cp1251 [string range [::http::data $token] 0 35000]]
::http::cleanup $token
regsub -- {;.*$} $type "" type
set len [string length $data]
if {$type ne "unknown" && [string match -nocase "*/*xml" $type]} {
if {$debug} {putlog "\[feed\] Info: Valid type $url."}
} elseif {
[regexp -nocase -- {<link.*?type="application/rss\+?x?m?l?".*?href=\"(.+?)\".*?/>} [regsub -nocase -- {</head>.*$} $data ""] -> url] || \
[regexp -nocase -- {<link.*?type="application/rss\+?x?m?l?".*?href="(.+?)"} [regsub -nocase -- {</head>.*$} $data ""] -> url] || \
[regexp -nocase -- {<link.*?type=\"?application/rss\+?x?m?l?\"?.*?href=\"?(.+?)\"?/>} [regsub -nocase -- {</head>.*$} $data ""] -> url]
} {
set url [string map {{&amp;} {&}} [string trim [regsub -- {\>.*$} $url ""] {" )].,}]]
if {$debug} {putlog "\[feed\] Info: Found RSS-feed: '$url'."}
if {[catch {set token [::http::geturl $url -timeout [expr $timeout * 1000] -protocol 1.0 -headers [list "Accept-Encoding" "None"] -binary 1 -command [list [namespace current]::data $chan $url $num $format $timecheck $string $auto]]} err]} {
if {$timecheck eq "0"} {putserv "PRIVMSG $chan :�� ������� ������������ � '$url' ($err)"}
}
return
} else {
if {$debug} {putlog "\[feed\] Warning: Type ($type) document not supported. Trying to parse anything."}
}
variable datafile
set f [open $datafile r]
set fdata [lrange [split [read $f] \n] 0 end-1]
close $f
if {$auto eq "1"} {
if {![string is space [set indx [lsearch -all -nocase -index 0 $fdata "$url"]]]} {
if {$chan ni [lindex $fdata $indx 2]} {
set amsg " �������� ����� $chan."
foreach {url_ format_ chan_ msg_ updated_} [lindex $fdata $indx] {break}
lappend chan_ $chan
set fdata [lreplace $fdata $indx $indx [list $url_ $format_ $chan_ $msg_ $updated_]]
set f [open $datafile w]
puts $f [join $fdata \n]
flush $f
close $f
} else {set amsg ""}
putserv "PRIVMSG $chan :����� '$url' ��� ���� � ������.$amsg ������ ������������ ������..."
set chan_ [join [lindex $fdata $indx 2]]
set msg_  [lindex $fdata $indx 3]
variable defformat
set format_ [lindex $fdata $indx 1]
if {[string is space $format_]} {set format_ $defformat} elseif {![string is space $format] && ![string equal $format $defformat]} {set format_ $format}
set fdata_ [lreplace $fdata $indx $indx [list $url $format_ $chan_ -NULL- [clock seconds]]]
set f [open $datafile w]
puts $f [join $fdata_ \n]
flush $f
close $f
set auto 0
unset -nocomplain fdata fdata_ f indx
return 0
} else {
set f [open $datafile a]
puts $f [list $url $format $chan "-NULL-" [clock seconds]]
flush $f
close $f
putserv "PRIVMSG $chan :����� '$url' ��������� � ������ �������."
unset -nocomplain fdata f indx
return 0
}
}
if {$timecheck eq "1" && ![string is space $string]} {
variable datafile; variable checklines; variable maxnews
set f [open $datafile r]
set fdata [lrange [split [read $f] \n] 0 end-1]
close $f
if {[catch {set RssData [lrange [parse $data $charset] 0 [expr $checklines - 1]]} err]} {putlog "\[feed\] Warning: \[timecheck\]: Error while getting info for feed '$url'. ([string totitle $err])"; return 0}
set tmpstr [list]
foreach _ $RssData {
foreach {name title link description date} $_ {break}
if {[string is space $name]} {set name "����������� ���"}
if {[string length $description] >= $maxlength} {set description "[string range $description 0 [expr $maxlength - 1]]..."}
set chanstring [subst -nocom [string map {%name% \$name %title% \$title %link% \$link %descr% \$description %date% \$date} [string map [list \] \\\] \[ \\\[ \$ \\\$ \\ \\\\] $format]]]
if {![string is space [set indx [lsearch -nocase -all -index 0 $fdata "*[string map {{http://} {}} $url]*"]]]} {
set url_ [lindex $fdata $indx 0]
set format_ [lindex $fdata $indx 1]
set chan_ [lindex $fdata $indx 2]
set strings [lindex $fdata $indx 3]
set strings2 ""; foreach _ $strings {
lappend strings2 [list [regsub -all -- {[^a-zA-Z�-��-߸�\x20]} [lindex $_ 0] {}] [lindex $_ 1]]
}
foreach string_ $strings {
set string [lindex $string_ 0]
if {[lsearch -nocase -index 0 $strings2 [regsub -all -- {[^a-zA-Z�-��-߸�\x20]} $chanstring {}]] != "-1"} {continue}
set tmpstr2 ""; foreach _ $tmpstr {
lappend tmpstr2 [list [regsub -all -- {[^a-zA-Z�-��-߸�\x20]} [lindex $_ 0] {}] [lindex $_ 1]]
}
if {[lsearch -nocase -index 0 $tmpstr2 [regsub -all -- {[^a-zA-Z�-��-߸�\x20]} $chanstring {}]] == "-1"} {
lappend tmpstr [list $chanstring [clock seconds]]
if {[llength $chan_] > 1} {
foreach _ $chan {
::ccs::put_msgdest $_ $chanstring
}
continue
} else {::ccs::put_msgdest $chan_ $chanstring}
}
}
if {[llength $tmpstr]} {
append strings " $tmpstr"
set strings [string map {{-NULL- } {}} $strings]
if {[llength $strings] > $maxnews} {set strings [lrange [lsort -index 1 -decreasing -real $strings] 0 [expr $maxnews - 1]]}
set fdata_ [lreplace $fdata $indx $indx [list $url_ $format_ $chan_ $strings [clock seconds]]]
set f [open $datafile w]
puts $f [join $fdata_ \n]
flush $f
close $f
}
continue
}
putlog "\[feed\] ERROR: Unable to find URL $url in datafile!!!"
continue
}
unset -nocomplain f fdata fdata_ RssData data charset name link description date url url_ format format_ chan chan_ string chanstring
return
} else {
if {[catch {set RssData [parse $data $charset]} err]} {
putserv "PRIVMSG $chan :������ ��� ��������� ����������. ([string totitle $err])"
return 0
}
set i 0
foreach line $RssData {
foreach {name title link description date} $line {break}
if {[string is space $name]} {set name "����������� ���"}
if {[string length $description] >= $maxlength} {set description "[string range $description 0 [expr $maxlength - 1]]..."}
if {[incr i] > $num} {break}
::ccs::put_msgdest $chan [subst -nocom [string map {%name% \$name %title% \$title %link% \$link %descr% \$description %date% \$date} [string map [list \] \\\] \[ \\\[ \$ \\\$ \\ \\\\] $format]]]
}
}
return
}

proc parse {data {charset ""}} {
variable debug
set data [string range $data 0 32767]
if {[string match "*<rss*" $data] || [string match "*<feed*" $data]} {
set burl ""
regexp -nocase -- {^.*?xml:base="(.*?)">} [string range $data 0 299] -> burl
regsub -all -- {[^A-Za-z\:\/\-\_0-9\.]} $burl "" burl
if {[string length $burl] > 150} {set burl ""}
foreach _ [split $data \n] {
if {[regexp -nocase -- {<?xml version=.*? encoding=(.*?)>} $_ -> charset]} {break} else {set charset ""}
}
if {$charset eq ""} { if {$debug} {putlog "\[feed\] ERROR: Unknown xml-format ��� unsupported type document."} }
regsub -all -- "\n|\r|\t" $data " " data
regsub -all -- {[\x20\x09]+} $data " " data
regsub -- {>.*?$} $charset "" charset
set charset [string tolower [string map -nocase {{UTF8} {utf-8} {windows-} {cp}} $charset]]
set encoding [regsub -all -nocase -- {[^\w\-\_]} [string tolower [string map -nocase {{windows-} {cp} {iso-} {iso} {utf8} {utf-8} {"} {} {'} {}} $charset]] ""]
if {$encoding ni [encoding names]} {set encoding utf-8}
# ��������� ������������� ��������� � �����:
# if {[string match "*���*" $url]} {set encoding cp1251}
if {$encoding ne "utf-8"} {set data [encoding convertfrom $encoding [encoding convertto cp1251 $data]]} else {set data [encoding convertfrom utf-8 [encoding convertto cp1251 $data]]}
if {![regexp -- {<channel>.*?<title.*?>(.*?)</title>.*?<item>} $data -> name] && ![regexp -- {^.*?<title.*?>(.*?)</title>} $data -> name]} {set name "����������� ���"}
set date "N/A"
regsub -- {^.*?(<item>|<entry>)} $data {\1} data
set data [string map -nocase {{<item>} \n {<entry>} \n "\x3C\x21\x5B\x43\x44\x41\x54\x41\x5B" "" "\x5D\x5D\x3E" "" "&#093;" {]} {<br />} { } {<p>} { } {<br>} { } {&lt;br /&gt;} { } {&lt;br/&gt;} { }} $data]
set tmp [list]
foreach _ [split $data \n] {
if {([regexp -nocase -- {<title>(.*?)</title>} $_ -> title] || [regexp -nocase -- {<title.*?>(.*?)</title>} $_ -> title]) && ([regexp -nocase -- {<link>(.*?)</link>} $_ -> link] || [regexp -nocase -- {<link.*?href="(.*?)"\s*?/>} $_ -> link] || [regexp -nocase -- {<link.*?>(.*?)</link>} $_ -> link])} {
if {![regexp -nocase -- {<pubDate>(.*?)?</pubDate>} $_ -> date] && ![regexp -nocase -- {<updated>(.*?)?</updated>} $_ -> date]} {set date "N/A"}
if {![regexp -nocase -- {<description>(.*?)</description>} $_ -> description] && ![regexp -nocase -- {<summary.*?>(.*?)</summary>} $_ -> description] && ![regexp -nocase -- {<content.*?>(.*?)</content.*?>} $_ -> description]} {set description "(�������� �� ��������)"}
if {[regexp -nocase -- {<description></description>} $_] && [regexp -nocase -- {<yandex:full-text>(.*?)</yandex:full-text>} $_ -> description]} {set description $description}
if {$description eq $link} {set description {\(�������� �� ��������\)}}
if {$burl != "" && [string first "http" $link] == -1} {set link "$burl$link"}
lappend tmp [list [[namespace current]::strip.html $name] [[namespace current]::strip.html $title] [string map {{&amp;} {&}} $link] [[namespace current]::strip.html $description] [string map {{, } " "} $date]]
}
}
if {![llength $tmp]} {return -code error "������ ��������"}
return $tmp
} {return -code error "�� ������� RSS/Atom �����"}
}

proc regsub-eval {re string cmd} {return [subst [regsub -all $re [string map {\[ \\[ \] \\] \$ \\$ \\ \\\\} $string] "\[format %c \[$cmd\]\]"]]}

proc strip.html {t} {
                regsub -all -nocase -- {<!\[CDATA\[(.*?)\]\]>} $t {\1} t
		regsub -all -nocase -- {<.*?>(.*?)</.*?>} $t {\1} t
		regsub -all -nocase -- {<.*?>} $t {} t
		set t [string map {{&amp;} {&}} $t]
		set t [string map -nocase {{&mdash;} {-} {&raquo;} {�} {&laquo;} {�} {&quot;} {"}  \
		{&lt;} {<} {&gt;} {>} {&nbsp;} { } {&amp;} {&} {&copy;} {�} {&#169;} {�} {&bull;} {�} {&#183;} {-} {&sect;} {�} {&reg;} {�} &#8214; || \
		&#38;      &     &#91;      (     &#92;      /     &#93;      )      &#123;     (     &#125;     ) \
		&#163;     �     &#168;     �     &#169;     �     &#171;     �      &#173;     �     &#174;     � \
		&#161;     �     &#191;     �     &#180;     �     &#183;     �      &#185;     �     &#187;     � \
		&#188;     �     &#189;     �     &#190;     �     &#192;     �      &#193;     �     &#194;     � \
		&#195;     �     &#196;     �     &#197;     �     &#198;     �      &#199;     �     &#200;     � \
		&#201;     �     &#202;     �     &#203;     �     &#204;     �      &#205;     �     &#206;     � \
		&#207;     �     &#208;     �     &#209;     �     &#210;     �      &#211;     �     &#212;     � \
		&#213;     �     &#214;     �     &#215;     �     &#216;     �      &#217;     �     &#218;     � \
		&#219;     �     &#220;     �     &#221;     �     &#222;     �      &#223;     �     &#224;     � \
		&#225;     �     &#226;     �     &#227;     �     &#228;     �      &#229;     �     &#230;     � \
		&#231;     �     &#232;     �     &#233;     �     &#234;     �      &#235;     �     &#236;     � \
		&#237;     �     &#238;     �     &#239;     �     &#240;     �      &#241;     �     &#242;     � \
		&#243;     �     &#244;     �     &#245;     �     &#246;     �      &#247;     �     &#248;     � \
		&#249;     �     &#250;     �     &#251;     �     &#252;     �      &#253;     �     &#254;     � \
		&#176;     �     &#8231;    �     &#716;     .     &#363;     u      &#299;     i     &#712;     ' \
		&#596;     o     &#618;     i     &apos;     ' } $t]
		set t [string map -nocase {&iexcl;    \xA1  &curren;   \xA4  &cent;     \xA2  &pound;    \xA3   &yen;      \xA5  &brvbar;   \xA6 \
		&sect;     \xA7  &uml;      \xA8  &copy;     \xA9  &ordf;     \xAA   &laquo;    \xAB  &not;      \xAC \
		&shy;      \xAD  &reg;      \xAE  &macr;     \xAF  &deg;      \xB0   &plusmn;   \xB1  &sup2;     \xB2 \
		&sup3;     \xB3  &acute;    \xB4  &micro;    \xB5  &para;     \xB6   &middot;   \xB7  &cedil;    \xB8 \
		&sup1;     \xB9  &ordm;     \xBA  &raquo;    \xBB  &frac14;   \xBC   &frac12;   \xBD  &frac34;   \xBE \
		&iquest;   \xBF  &times;    \xD7  &divide;   \xF7  &Agrave;   \xC0   &Aacute;   \xC1  &Acirc;    \xC2 \
		&Atilde;   \xC3  &Auml;     \xC4  &Aring;    \xC5  &AElig;    \xC6   &Ccedil;   \xC7  &Egrave;   \xC8 \
		&Eacute;   \xC9  &Ecirc;    \xCA  &Euml;     \xCB  &Igrave;   \xCC   &Iacute;   \xCD  &Icirc;    \xCE \
		&Iuml;     \xCF  &ETH;      \xD0  &Ntilde;   \xD1  &Ograve;   \xD2   &Oacute;   \xD3  &Ocirc;    \xD4 \
		&Otilde;   \xD5  &Ouml;     \xD6  &Oslash;   \xD8  &Ugrave;   \xD9   &Uacute;   \xDA  &Ucirc;    \xDB \
		&Uuml;     \xDC  &Yacute;   \xDD  &THORN;    \xDE  &szlig;    \xDF   &agrave;   \xE0  &aacute;   \xE1 \
		&acirc;    \xE2  &atilde;   \xE3  &auml;     \xE4  &aring;    \xE5   &aelig;    \xE6  &ccedil;   \xE7 \
		&egrave;   \xE8  &eacute;   \xE9  &ecirc;    \xEA  &euml;     \xEB   &igrave;   \xEC  &iacute;   \xED \
		&icirc;    \xEE  &iuml;     \xEF  &eth;      \xF0  &ntilde;   \xF1   &ograve;   \xF2  &oacute;   \xF3 \
		&ocirc;    \xF4  &otilde;   \xF5  &ouml;     \xF6  &oslash;   \xF8   &ugrave;   \xF9  &uacute;   \xFA \
		&ucirc;    \xFB  &uuml;     \xFC  &yacute;   \xFD  &thorn;    \xFE   &yuml;     \xFF} $t]
		set t [[namespace current]::regsub-eval {&#([0-9]{1,5});} $t {string trimleft \1 "0"}]
		regsub -all {[\x20\x09]+} $t " " t
		regsub -all -nocase -- {<.*?>} $t {} t
                regsub -all {\s+} $t " " t; regsub -all {^\s+} $t "" t; regsub -all {\s+$} $t "" t
		return $t
}
	
bind pub - $::gprefix(1)lenta [namespace current]::lentaread
bind pub - $::gprefix(1)����� [namespace current]::lentaread
	
proc lentaread {nick uhost hand chan text} {
set text [regsub -all -- {[^a-zA-Z0-9\-\_\:\/\.]} $text ""]
if {[string is space $text] || ![regexp -nocase -- {^(http://)?(lenta\.ru\/.+?)$} $text - _ text]} { ::ccs::put_msgdest -type notice $nick "������: $::lastbind <������ �� ������� � lenta.ru> - ������ �������."; return}
variable useragent	
::http::config -useragent $useragent
if {[string index $text end] != "/"} {append text "/"}
if {[catch {set t [::http::geturl "http://$text" -timeout 10000 -binary false]} err]} {
::ccs::put_msgdest -type notice $nick "�� ���� ����������� � http://$text... ��������� ������� �����."
return
}
if {[::http::status $t] eq "ok" && [::http::ncode $t] == "200"} {
set data [::http::data $t]
::http::cleanup $t
regsub -all -- {\n|\r|\t} $data { } data
set title [lindex [regexp -nocase -inline -- {<title>(.+?)</title>} $data] 1]
regsub -nocase -- {^.*?<!-- testcom /news} $data {} data
if {[string is space $title]} {
::ccs::put_msgdest -type notice $nick "������ ��������..."
unset -nocomplain data
return
}
if {![regexp -nocase -- {-->\s*(.*?)\s*<p class=links>.*?<BR clear=all>} $data - data] && ![regexp -nocase -- {-->\s*(.*?)\s*<BR clear=all>.*?bottom-menu} $data - data] } {
::ccs::put_msgdest -type notice $nick "������ ��������..."
unset -nocomplain data
return
}
regsub -all -nocase -- {<P class=links>.*?$} $data {} data
set data [strip.html [string map -nocase {{<p>} { }} $data]]
::ccs::put_msgdest $nick $::gcolor(6)$title
::ccs::put_msgdest $nick $data
unset -nocomplain data
return
} else {
::ccs::put_msgdest -type notice $nick "� ���������, ������ ������ �������� ��� ([::http::code $t]) ��� ����-���."
::http::cleanup $t
return
}
}
}

if {![info exists ::ccs::version]} {die "!!! Not Found CCS.tcl !!!"}
