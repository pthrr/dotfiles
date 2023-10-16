#include <iostream>
#include <stdio.h>
#include <string>

static const std::string COMMAND_GET_INPUT_DEVICE_EVENT_NUMBER =
    "grep -E 'Handlers|EV=' /proc/bus/input/devices |"
    "grep -B1 'EV=120013' |"
    "grep -Eo 'event[0-9]+' |"
    "grep -Eo '[0-9]+' |"
    "tr -d '\n'";

std::string executeCommand( const char* cmd )
{
    FILE* pipe = popen( cmd, "r" );
    char buffer[128];
    std::string result = "";
    while( !feof( pipe ) )
        if( fgets( buffer, 128, pipe ) != NULL )
            result += buffer;
    pclose( pipe );
    return result;
}

std::string getInputDevicePath()
{
    return "/dev/input/event" + executeCommand( COMMAND_GET_INPUT_DEVICE_EVENT_NUMBER.c_str() );
}

int main()
{
    std::cout << getInputDevicePath() << std::endl;
    return 0;
}
