@set MK=8535
@set PRG=usbasp
@set FLASHFILE=flowmeter.hex
@set AVRDUDEPATH=C:\soft\avrdude\avrdude\avrdude.exe

REM FLASH
%AVRDUDEPATH% -F -p %MK% -c %PRG% -e -U flash:w:%FLASHFILE%