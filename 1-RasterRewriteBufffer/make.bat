@echo off

set WRITE="C:\C64\Tools\vice\bin\c1541.exe" -attach "./bin/DISK.D81" 8 -write
set FORMAT="C:\C64\Tools\vice\bin\c1541.exe" -format "disk,0" d81 "./bin/DISK.D81"
set KICKASM=java -cp Z:\Projects\Mega65\_build_utils\kickass.jar kickass.KickAssembler65CE02  -vicesymbols -showmem 
set DEPLOY="C:\C64\Tools\m65_connect\M65Connect Resources\m65.exe" -l COM6 -F -r 
set ASP65="node ./_include/aseparse65/asp65 parse -i "


echo ASSEMBLING SOURCES...
%KICKASM%  main.s -odir ./bin

echo CREATING DISK IMAGE AND BOOT PRG...
rem %FORMAT%
rem %WRITE% "./bin/main.prg" main

echo DEPLOYING...
%DEPLOY% "./bin/main.prg"
"C:\Program Files\xemu\xmega65.exe" -besure -forcerom -loadrom "../roms/920180.bin" -prg "./bin/main.prg"


