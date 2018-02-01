###############################################################################
#
# ������ ������������� ������������ �� NickServ
#
# ���������:
#	1. ����������� ������ � ����� scripts.
#	2. �������� � eggdrop.conf:
#			source scripts/b-ident.tcl
#	3. ��������� ������ � ���������� pass ����.
#	4. ������������� ���� �������� .rehash ��� .restart.
#
###############################################################################
# 
#  WeNet @ #eggdrop
#  �����: Buster <VirFX@mail.ru>
# 
###############################################################################

# ������ �� ��� ����
set pass "������"


# ������ ������ �� �������, ���� �� ������� � ����� ���������
set init-server {putlog "NickIdent: ������������� ����: $nick"; putquick "PRIVMSG NickServ :IDENTIFY $pass"}
bind evnt - init-server nickident:init_server

proc nickident:init_server {type} {
  putquick "ISON Nickserv"
}
bind raw - 303 nickident:ison
proc nickident:ison {n h paras} {
	global nick pass
	
	if {$paras == ""} {
		putlog "NickIdent: ������ ������������� ����� 2 ���"
		timer 2 {putquick "ISON Nickserv"}
	} else {
		if {[isbotnick $nick]} {
			putlog "NickIdent: ������������� �� ��� $nick"
			putquick "PRIVMSG NickServ :IDENTIFY $pass"
		} else {
			putlog "NickIdent: ���������� ��������� ������ $nick"
			putquick "PRIVMSG NickServ :GHOST $nick $pass"
		}
	}
}
bind raw - 433 nickident:busy
proc nickident:busy { from keyword text } {
	global nick
	
	if {[isbotnick $nick]} {
		putlog "NickIdent: ����� ���� �� $nick"
		putquick "NICK :$nick"
		putquick "ISON Nickserv"
	}
}
