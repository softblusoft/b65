# Copyright 2023 Luca Bertossi
#
# This file is part of B65.
# 
#     B65 is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     B65 is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with B65.  If not, see <http://www.gnu.org/licenses/>.

rom2coe: rom2coe.o
	gcc rom2coe.o -o rom2coe

rom2coe.o: rom2coe.c $(HEADERS)
	gcc -c rom2coe.c -o rom2coe.o

clean:
	-rm -f rom2coe.o
	-rm -f rom2coe