################################################################################
#	Makefile for shalarm.sh
#
#	Technically, no 'making' occurs, since it's just a shell script, but
#	let us not quibble over trivialities such as these.
################################################################################
ROOTPATH=
PREFIX=$(ROOTPATH)/usr
SRC=src
SRCFILE=shalarm.sh
DESTFILE=shalarm
DOC=doc
DATA=data
MANPATH=$(PREFIX)/share/man/man1
CFGPATH=$(ROOTPATH)/etc
DATAPATH=$(PREFIX)/share/shalarm

install:
	install -D -g 0 -o 0 -m 0755 $(SRC)/$(SRCFILE) $(PREFIX)/bin/$(DESTFILE)
	install -v -D -g 0 -o 0 -m 0644 $(DATA)/ring.wav $(DATAPATH)/ring.wav
	install -v -D -g 0 -o 0 -m 0644 LICENSE $(DATAPATH)/LICENSE
	install -v -D -g 0 -o 0 -m 0644 README $(DATAPATH)/README
	install -D -v -g 0 -o 0 -m 0644 $(DATA)/shalarm.cfg $(CFGPATH)/shalarm.cfg
	install -D -g 0 -o 0 -m 0644 $(DOC)/shalarm.1 $(MANPATH)/shalarm.1

uninstall:
	rm -f $(PREFIX)/bin/$(DESTFILE)
	rm -f $(DATAPATH)/ring.wav
	rm -f $(DATAPATH)/LICENSE
	rm -f $(DATAPATH)/README
	rmdir $(DATAPATH)
	rm -f $(CFGPATH)/shalarm.cfg
	rm -f $(MANPATH)/shalarm.1
