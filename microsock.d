version (Windows)
{
    pragma(lib, "ws2_32.lib");
    pragma(lib, "wsock32.lib");

    private import core.sys.windows.winsock2;

    //private import core.sys.windows.windows, std.windows.syserror;
    private alias _ctimeval = core.sys.windows.winsock2.timeval;
    private alias _clinger = core.sys.windows.winsock2.linger;

    enum socket_t : SOCKET
    {
        INVALID_SOCKET
    }

    private const int _SOCKET_ERROR = SOCKET_ERROR;

    private int _lasterr() nothrow @nogc
    {
        return WSAGetLastError();
    }
}
else version (Posix)
{
    version (linux)
    {
        enum : int
        {
            TCP_KEEPIDLE = 4,
            TCP_KEEPINTVL = 5
        }
    }

    private import core.sys.posix.netdb;

    private import core.sys.posix.sys.un : sockaddr_un;

    private import core.sys.posix.fcntl;

    private import core.sys.posix.unistd;

    private import core.sys.posix.arpa.inet;

    private import core.sys.posix.netinet.tcp;

    private import core.sys.posix.netinet.in_;

    private import core.sys.posix.sys.socket;

    private import core.stdc.errno;

    enum socket_t : int32_t
    {
        init = -1
    }

    private const int _SOCKET_ERROR = -1;

    private enum : int
    {
        SD_RECEIVE = SHUT_RD,
        SD_SEND = SHUT_WR,
        SD_BOTH = SHUT_RDWR
    }

    private int _lasterr() nothrow @nogc
    {
        return errno;
    }
}
else
{
    static assert(0); // No socket support yet.
}

//ubyte[] recv(Socket s, )

shared static this() @system
{
    version (Windows)
    {
        WSADATA wd;

        // Winsock will still load if an older version is present.
        // The version is just a request.
        int val;
        val = WSAStartup(0x2020, &wd);
        if (val) // Request Winsock 2.2 for IPv6.
            assert(0, "Unable to initialize socket library");
    }

}

shared static ~this() @system nothrow @nogc
{
    version (Windows)
    {
        WSACleanup();
    }
}

///ctfe-able version of inet_addr;
uint inet_addr(string ip)
{
    uint result;

    uint p;
    uint n;

    foreach (i, char c; ip)
    {
        if (c == '.')
        {
            version (BigEndian)
            {
                result |= n << (24 - 8 * p++);
            }
            else version (LittleEndian)
            {
                result |= n << (8 * p++);
            }
            else
                static assert(0, "Nither BigEndian nor LittleEndian");

            n = 0;
            assert(0, "only x.x.x.x is accepted. Given: " ~ ip);
        }
        else if (c >= '0' && c <= '9')
        {
            n *= 10;
            n += c - '0';
            assert(n < 256);
        }
        else
            assert(0, "only x.x.x.x is accepted. Given: " ~ ip);
    }

    version (BigEndian)
    {
        result |= n;
    }
    else version (LittleEndian)
    {
        result |= n << 24;
    }
    else
        static assert(0, "Nither BigEndian nor LittleEndian");

    assert(p == 3);
    return result;
}

version (LittleEndian)
{
    static assert(inet_addr("127.0.0.1") == 16777343);
    static assert(inet_addr("129.24.0.25") == 419436673);
}
else version (BigEndian)
{
    static assert(inet_addr(("127.0.0.1") == 2130706433));
    static assert(inet_addr("129.24.0.25") == 2165833753);
}
