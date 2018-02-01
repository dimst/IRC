###############################################################################
#
# Скрипт идентификации пользователя на NickServ
#
# Установка:
#	1. Скопировать скрипт в папку scripts.
#	2. Добавить в eggdrop.conf:
#			source scripts/b-ident.tcl
#	3. Прописать пароль в переменной pass ниже.
#	4. Перезапустить бота командой .rehash или .restart.
#
###############################################################################
# 
#  WeNet @ #eggdrop
#  Автор: Buster <VirFX@mail.ru>
# 
###############################################################################

# Пароль на ник бота
set pass "пароль"


# Дальше ничего не трогать, если не уверены в своих действиях
set init-server {putlog "NickIdent: Идентификации ника: $nick"; putquick "PRIVMSG NickServ :IDENTIFY $pass"}
bind evnt - init-server nickident:init_server

proc nickident:init_server {type} {
  putquick "ISON Nickserv"
}
bind raw - 303 nickident:ison
proc nickident:ison {n h paras} {
	global nick pass
	
	if {$paras == ""} {
		putlog "NickIdent: Повтор идентификации через 2 сек"
		timer 2 {putquick "ISON Nickserv"}
	} else {
		if {[isbotnick $nick]} {
			putlog "NickIdent: Идентификация на ник $nick"
			putquick "PRIVMSG NickServ :IDENTIFY $pass"
		} else {
			putlog "NickIdent: Завершение зависшего сеанса $nick"
			putquick "PRIVMSG NickServ :GHOST $nick $pass"
		}
	}
}
bind raw - 433 nickident:busy
proc nickident:busy { from keyword text } {
	global nick
	
	if {[isbotnick $nick]} {
		putlog "NickIdent: Смена ника на $nick"
		putquick "NICK :$nick"
		putquick "ISON Nickserv"
	}
}
