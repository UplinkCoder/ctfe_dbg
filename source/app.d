import arsd.simpledisplay;
import std.conv;
uint b4toi(ubyte[4] b4)
{
    uint result;

    foreach (i, b; b4)
    {
        result |= b << i * 8;
    }

    return result;
}

struct DebuggerClientState
{
    ubyte[8192] recvBuffer;

    uint dmdIp = b4toi([127, 0, 0, 1]); /// not use for now
    ushort dmdPort; /// a non-zero means we are connect on that port;
    string source;
    uint currentLine;

    string VarName;
    ushort* NumberVariable;
    uint Number;
    bool numberInput;

    bool commandInput;
    char[256] commandBuffer;
    int commandLength;

    string commandString()
    {
        return commandLength ? cast(string)(commandBuffer[0 .. commandLength]) : null;
    }

    string command()
    {
        return commandInput ? null : commandString;
    }

    void delegate(string) StatusLine = null;

    void UpdateStatusLine()
    {
        StatusLine(VarName ? VarName ~ to!string(Number) : to!string(Number));
    }

    void NumberInput(ushort* varP, string varName = null)
    {
        if (varName)
        {
            VarName = varName ~ ": "; 
            StatusLine(VarName);
        }
        numberInput = true;
        NumberVariable = varP;
    }
}

ushort findDmd(ushort[] portList)
{
    return 0;
}

void main()
{

    DebuggerClientState state;

    auto window = new SimpleWindow(Size(1024, 786), "ctfe_dbg");
    immutable textStart = window.height / 2;

    int y = textStart;
    import std.stdio;
    writeln(XOpenDisplay(null));

    void StatusLine(string text)
    {
        auto painter = window.draw();
        int y = window.height - painter.fontHeight - 2;

        if (text is null)
        {
            painter.outlineColor = Color.white;
            painter.fillColor = Color.white;
            painter.drawRectangle(Point(0, y), window.width, painter.fontHeight + 2);
        }

        painter.outlineColor = Color.red;
        painter.fillColor = Color.gray;
        painter.drawRectangle(Point(0, y), window.width, painter.fontHeight + 2);

        painter.outlineColor = Color.green;
        painter.drawText(Point(10, y), text);
    }

    state.StatusLine = &StatusLine;

    void addLine(string text)
    {
        auto painter = window.draw();
        //painter.fontHeight = window.height / 80;

        if (y + painter.fontHeight * 3 >= window.height)
        {
            painter.scrollArea(Point(0, textStart), window.width,
                    window.height - painter.fontHeight*4, 0, painter.fontHeight);
            y -= painter.fontHeight + 2;
        }

        painter.outlineColor = Color.red;
        painter.fillColor = Color.black;
        painter.drawRectangle(Point(0, y), window.width, painter.fontHeight + 2);

        painter.outlineColor = Color.green;

        painter.drawText(Point(10, y), text);

        y += painter.fontHeight + 2;
    }

    window.setResizeGranularity(2, 2);
    //window2.eventLoop(1000, delegate () {return ;});
    window.eventLoop(4000, delegate() {
        with (state)
        {
            if (!dmdPort && !numberInput && !commandInput)
            {
                ushort[] portList = [0xc7fe];
                dmdPort = findDmd(portList);
                if (dmdPort)
                {
                    // TODO on succsessful connection
                }
                else
                {
                    StatusLine("Did not find no dmd on ports: " ~ to!string(portList));
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

            if (key >= Key.N0 && key <= Key.N9)
            {
                import std.math;

                if (numberInput)
                {
                    uint n = (key - Key.N0);

                    Number *= 10;
                    Number += n;
                    UpdateStatusLine();
                }
            }
            else
            {
                if (numberInput)
                {
                    if (key == Key.Backspace)
                    {
                        Number /= 10;
                        UpdateStatusLine();
                        return;
                    }
                    numberInput = false;
                    *NumberVariable = cast(ushort) Number;
                    addLine("Number: " ~ to!string(Number));
                    Number = 0;
                    StatusLine(null);
                }
                else if (commandInput)
                {
                    if (key >= Key.A && key <= Key.Z)
                    {
                        commandBuffer[commandLength++] = cast(char)((event.modifierState & ModifierState.shift ? 'A' : 'a') + (key - Key.A));
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
                            addLine(": " ~ command);
                    }
                    
                    StatusLine(": " ~ cast(string) commandBuffer[0 .. commandLength]);
                }
                else if (key == Key.Shift) 
                {}
                else
                {
                    addLine(to!string(event));
                }

                if (key == Key.F4 || key == Key.Escape || command == "q")
                    window.close();


                if (key == Key.Semicolon && event.modifierState & ModifierState.shift)
                {
                    StatusLine(": ");
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
