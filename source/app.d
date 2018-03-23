import arsd.simpledisplay;
import std.conv;

ushort findDmd(ushort[] portList)
{
    return 0;
}

uint b4toi(ubyte[4] b4)
{
    uint result;

    foreach (i, b; b4)
    {
        result |= b << i * 8;
    }

    return result;
}

struct v2
{
    float x, y;
}

enum PacketType : uint
{
    Invalid,

    Request,
    Response
}

alias Response = PacketType.Response;
alias Request = PacketType.Request;

align(1) struct DebugPacket
{
align(4):
    PacketType type;
    int[7] content;
}

struct DebuggerClientState
{
    OperatingSystemFont font;
    SimpleWindow window;

    ubyte[8192] recvBuffer;

    uint dmdIp = b4toi([127, 0, 0, 1]); /// not use for now
    ushort dmdPort; /// a non-zero means we are connect on that port;
    string source;
    uint currentLine;

    string VarName;
    ushort* NumberVariable;
    uint Number;
    bool numberInput;
    void delegate(int) numberInputCallBack = null;

    bool commandInput;
    char[256] commandBuffer;
    int commandLength;

    char[265][32] commandHistoryBuffer;
    int commandHistoryLength;

    string blPrefix;

    void setBreakPoint(int n)
    {
        TopLine("set breakpoint " ~ to!string(n));
    }

    string commandString()
    {
        return commandLength ? cast(string)(commandBuffer[0 .. commandLength]) : null;
    }

    string command()
    {
        return commandInput ? null : commandString;
    }

    void BottomLine(string text, Color textColor = Color.green)
    {
        auto painter = window.draw();
        painter.setFont(font);
        int y = window.height - painter.fontHeight;

        if (text is null)
        {
            painter.outlineColor = Color.white;
            painter.fillColor = Color.white;
            painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);
            return;
        }

        painter.outlineColor = Color.red;
        painter.fillColor = Color.gray;
        painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);

        painter.outlineColor = textColor;
        painter.drawText(Point(10, y), text);
    }

    void TopLine(string text, Color textColor = Color.green)
    {
        auto painter = window.draw();
        int y = 0;

        if (text is null)
        {
            painter.outlineColor = Color.white;
            painter.fillColor = Color.white;
            painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);
            return;
        }

        painter.outlineColor = Color.red;
        painter.fillColor = Color.gray;
        painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);

        painter.outlineColor = textColor;
        painter.drawText(Point(10, y), text);
    }

    void addLine(string text)
    {
        const textStart = window.height / 2;

        static int y;
        if (!y)
            y = textStart;

        auto painter = window.draw();
        painter.setFont(font);
        //painter.fontHeight = window.height / 80;

        if (y + painter.fontHeight * 3 >= window.height)
        {
            y = textStart;
        }

        painter.outlineColor = Color.red;
        painter.fillColor = Color.black;
        painter.drawRectangle(Point(0, y), window.width, painter.fontHeight + 2);

        painter.outlineColor = Color.green;

        painter.drawText(Point(10, y), text);

        y += painter.fontHeight + 2;
    }


    void NumberInput(string blPrefix, void delegate(int n) cb)
    {
        NumberInput(cb, blPrefix);
    }

    void NumberInput (void delegate(int n) cb, string blPrefix = null)
    {
        if (blPrefix)
            this.blPrefix = blPrefix;
        assert(!numberInputCallBack);
        numberInputCallBack = cb;
        numberInput = true;
    }

}

struct Conn
{
    enum ConnType
    {
        invalid,

        udp,
        tcp
    }

    ushort srcPort;
    ushort dstPort;
    uint srcIp;
    uint dstIp;
    void[] sendBuffer;
    void[] recvBuffer;

}

ushort findDmdPort(ushort[] portList = [0xC7F3])
{
	return 0;
}

bool discoverDmd()
{
	return true;
}

void main()
{

    DebuggerClientState state;
    auto disp = XOpenDisplay(null);
    auto screenDim = v2(DisplayWidth(disp, 0), DisplayHeight(disp, 0));

    state.window = new SimpleWindow(Size(1024, 786), "ctfe_dbg");
    state.font = new OperatingSystemFont("Arial.ttf", 24);

    import std.stdio;

    if (state.font.isNull)
    {
        state.TopLine("failed to load font", Color.yellow);
    }

    void handleCommand(string _command)
    {
        with(state) switch (_command)
        {
        case "quit", "q":
            window.close();
            break;
        case "help", "h":
            {
                TopLine("I'd show help here ... but there is nothing to show");
                BottomLine(null);
            }
            break;
        case "clear", "c":
            {
                TopLine(null);
                BottomLine(null);
            }
            break;
        case "b":
            {
                NumberInput("Breakpoint: ", &setBreakPoint);
            }
            break;
        default:
            {
                TopLine("No such command: " ~ _command);
                BottomLine(null);
            }
            break;
        }
    }

    state.window.setResizeGranularity(2, 2);
    //window2.eventLoop(1000, delegate () {return ;});
    state.window.eventLoop(4000, delegate() {
        with (state)
        {
            if (!dmdPort && !numberInput && !commandInput)
            {
                ushort[] portList = [0xc7fe];
                dmdPort = findDmdPort(portList);
                if (dmdPort)
                {
                    // TODO on succsessful connection
                }
                else
                {
                    TopLine("Did not find no dmd on ports: " ~ to!string(portList), Color.yellow);
                }
            }

            //        addLine("Timer went off!");
            return;
        }
    }, (KeyEvent event) {
        immutable key = event.key;
        with (state)
        {
            import std.datetime : Clock, msecs;

            alias now = Clock.currTime;
            static typeof(now()) lastTime;
            static typeof(event.key) oldKey;

            if (!event.pressed)
            {
                return;
            }

            lastTime = now;
            oldKey = key;

            {
                if (numberInput)
                {
                    if (key >= Key.N0 && key <= Key.N9)
                    {
                        import std.math;

                        uint n = (key - Key.N0);

                        Number *= 10;
                        Number += n;
                        if (blPrefix)
                            BottomLine(" " ~ blPrefix ~ Number.to!string);
                        return;
                    }
                    if (key == Key.Backspace)
                    {
                        Number /= 10;
                        return;
                    }

                    numberInput = false;
                    if (numberInputCallBack !is null)
                    {
                        numberInputCallBack(Number);
                        numberInputCallBack = null;
                    }
                    else
                        assert(0, "numberInputCallBack has to be set before we can enter number input");

                    BottomLine("Number: " ~ to!string(Number));
                    Number = 0;
                    BottomLine(null);
                }
                else if (commandInput)
                {
                    if (key >= Key.A && key <= Key.Z)
                    {
                        commandBuffer[commandLength++] = cast(char)((event.modifierState & ModifierState.shift
                            ? 'A' : 'a') + (key - Key.A));
                    }
                    else if (key >= Key.N0 && key <= Key.N9)
                    {
                        commandBuffer[commandLength++] = cast(char)('0' + key - Key.N0);
                    }
                    else if (key == Key.Space)
                    {
                        commandBuffer[commandLength++] = ' ';
                    }
                    else if (key == Key.Backspace)
                    {
                        if (commandLength)
                            commandLength--;
                    }
                    else if (key == Key.Enter)
                    {
                        commandInput = false;
                        if (commandLength)
                            handleCommand(command);
                        return;
                    }
                    else if (key == Key.Up)
                    {
                        TopLine("We should show history now", Color.yellow);
                    }

                    BottomLine(": " ~ cast(string) commandBuffer[0 .. commandLength]);
                }
                else if (key == Key.Shift)
                {
                }
                else
                {
                    addLine(to!string(event));
                }

                if (key == Key.F4 || key == Key.Escape || (!commandInput && key == Key.Q))
                    window.close();

                if (key == Key.Semicolon && event.modifierState & ModifierState.shift)
                {
                    BottomLine(": ");
                    commandLength = 0;
                    commandInput = true;
                }

            }

        }
    }, delegate(MouseEvent event) {
        return;
        //  addLine(to!string(event));
    },);
}
