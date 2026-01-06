# C application to close cleanly applications that respect ICCCM WM_DELETE_WINDOW
gcc input.c -o output -lX11 to build

script needs some cleaning, but it is for running before shutdown and checking programs that has WM_DELETE_WINDOW
