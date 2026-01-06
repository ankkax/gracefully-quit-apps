# C application to close cleanly applications that respect ICCCM WM_DELETE_WINDOW
gcc input.c -o output -lX11 to build

script needs some cleaning, but it is for running before shutdown and checking programs that has WM_DELETE_WINDOW

# quit.sh Script for shutting down or rebooting
Some applications like steam need to close separately, because it hangs if you just use close window command, might also be a problem wiht other programs that closes to tray
