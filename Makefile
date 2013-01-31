################################################################################
#	Makefile for shalarm.sh
#
#	Technically, no 'making' occurs, since it's just a shell script, but
#	let us not quibble over trivialities such as these.
################################################################################
PREFIX=/usr
SRC=src
SRCFILE=shalarm.sh
DESTFILE=shalarm
DOC=doc
DATA=data
MANPATH=$(PREFIX)/share/man/man1
CFGPATH=/etc
DATAPATH=$(PREFIX)/share/shalarm

install:
	install -g 0 -o 0 -m 0755 $(SRC)/$(SRCFILE) $(PREFIX)/bin/$(DESTFILE)
	install -v -D -g 0 -o 0 -m 0644 $(DATA)/ring.wav $(DATAPATH)/ring.wav
	install -v -g 0 -o 0 -m 0644 $(DATA)/shalarm.cfg $(CFGPATH)/shalarm.cfg
	install -g 0 -o 0 -m 0644 $(DOC)/shalarm.1 $(MANPATH)

uninstall:
	rm -f $(PREFIX)/bin/$(DESTFILE)
	rm -f $(DATAPATH)/ring.wav
	rmdir $(DATAPATH)
	rm -f $(CFGPATH)/shalarm.cfg
	rm -f $(MANPATH)/shalarm.1
