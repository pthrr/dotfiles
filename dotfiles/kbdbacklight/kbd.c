#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

static char dummybuf[8192];

#ifndef IDLE_MSEC
#define IDLE_MSEC 5000
#endif

#ifndef BRGHT_OFF
#define BRGHT_OFF '0'
#endif
#ifndef BRGHT_MED
#define BRGHT_MED '1'
#endif
#ifndef BRGHT_MAX
#define BRGHT_MAX '2'
#endif

volatile sig_atomic_t running = 1;

void term( int signum )
{
    // sigterm == 15
    running = 0;
}

int main( int argc, char* argv[] )
{
    struct sigaction action;
    struct pollfd pfd;
    int rc, blfd;
    int timeout, prev = -1;
    char bm = BRGHT_MED;

    memset( &action, 0, sizeof( struct sigaction ) );
    action.sa_handler = term;
    sigaction( SIGTERM, &action, NULL );

    blfd = open( "/sys/class/leds/tpacpi::kbd_backlight/brightness", O_WRONLY );

    // needs the event bound to the keyboard
    // for Xorg ie find using
    //  cat /var/log/Xorg.0.log | grep "keyboard.*event"
    //  cat ~/.local/share/xorg/Xorg.0.log | grep "keyboard.*event"
    pfd.fd = open( "/dev/input/event0", O_RDONLY );
    pfd.events = POLLIN;
    timeout = IDLE_MSEC;

    while( running ) {
        rc = poll( &pfd, 1, timeout );
        if( rc ) {
            printf( "pressed" );
            /* got keyboard input, flush it all and
        * wait for the next event.
        */
            read( pfd.fd, dummybuf, sizeof( dummybuf ) );
            /* timeout = IDLE_MSEC; */
            /* bm = BRGHT_MED; */
        }
        else {
            /* once we've gotten a timeout, turn off
        * kbd backlight and wait forever for
        * the next keypress
        */
            /* timeout = -1; */
            /* bm = BRGHT_OFF; */
        }
        /* if( bm == prev ) */
        /*     continue; */

        /* lseek( blfd, 13, SEEK_SET ); */
        /* write( blfd, &bm, 1 ); */
        /* prev = bm; */
    }
    // clean up after sigterm
    /* bm = BRGHT_OFF; */
    /* lseek( blfd, 13, SEEK_SET ); */
    /* write( blfd, &bm, 1 ); */
}
