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

struct v2
{
    float x, y;
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

    void delegate(string) BottomLine = null;
	void delegate(string) TopLine = null;

    void UpdateBottomLine()
    {
        BottomLine(VarName ? VarName ~ to!string(Number) : to!string(Number));
    }

    void NumberInput(ushort* varP, string varName = null)
    {
        if (varName)
        {
            VarName = varName ~ ": "; 
            BottomLine(VarName);
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
    auto disp = XOpenDisplay(null);
    auto screenDim = v2(DisplayWidth(disp, 0), DisplayHeight(disp, 0));

    auto window = new SimpleWindow(Size(1024, 786), "ctfe_dbg");
    immutable textStart = window.height / 2;

    int y = textStart;
    import std.stdio;

    void BottomLine(string text)
    {
        auto painter = window.draw();
        int y = window.height - painter.fontHeight;

        if (text is null)
        {
            painter.outlineColor = Color.white;
            painter.fillColor = Color.white;
            painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);
			return ;
        }

        painter.outlineColor = Color.red;
        painter.fillColor = Color.gray;
        painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);

        painter.outlineColor = Color.green;
        painter.drawText(Point(10, y), text);
    }

	void TopLine(string text)
	{
		auto painter = window.draw();
		int y = 0;
		
		if (text is null)
		{
			painter.outlineColor = Color.white;
			painter.fillColor = Color.white;
			painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);
			return ;
		}
		
		painter.outlineColor = Color.red;
		painter.fillColor = Color.gray;
		painter.drawRectangle(Point(0, y), window.width, painter.fontHeight);
		
		painter.outlineColor = Color.green;
		painter.drawText(Point(10, y), text);
	}


    state.BottomLine = &BottomLine;
	state.TopLine = &TopLine;

	void handleCommand(string command)
	{
		switch(command)
		{
			case "quit" :
				window.close();
				break;
			case "help" :
				TopLine("I'd show help here ... but there is nothing to show");
				break;
			case "clear" :
			{
				TopLine(null);
				BottomLine(null);
			}
				break;
			default :
				TopLine("No such command: " ~ command);
				break;
		}
	}

    void addLine(string text)
    {
        auto painter = window.draw();
        //painter.fontHeight = window.height / 80;

        if (y + painter.fontHeight * 3 >= window.height)
        {
            painter.scrollArea(Point(0, textStart), window.width,
                    window.height - (window.height / 2) - painter.fontHeight*3, 0, painter.fontHeight);
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
                    BottomLine("Did not find no dmd on ports: " ~ to!string(portList));
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
                    UpdateBottomLine();
                }
            }
            else
            {
                if (numberInput)
                {
                    if (key == Key.Backspace)
                    {
                        Number /= 10;
                        UpdateBottomLine();
                        return;
                    }
                    numberInput = false;
                    *NumberVariable = cast(ushort) Number;
                    addLine("Number: " ~ to!string(Number));
                    Number = 0;
                    BottomLine(null);
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
    						handleCommand(command);
                    }
                    
                    BottomLine(": " ~ cast(string) commandBuffer[0 .. commandLength]);
                }
                else if (key == Key.Shift) 
                {}
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
