
alls = h33yfix.obj
asmc = ml
link = $(NTMAKEENV)\bin16\link16
rm   = del

all: $(alls) clean

.asm.obj:
	$(asmc) /nologo /omf /c $<
	$(link) /NOLOGO /NODEFAULTLIBRARYSEARCH $@,$*.bin,$*.map,,,

@(alls) :

clean:
	-@$(rm) $(alls)
